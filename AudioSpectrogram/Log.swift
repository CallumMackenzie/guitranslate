//
//  Log.swift
//  Guitranslate
//
//  Created by Callum MacKenzie on 2024-05-22.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation

class PrintLogOutput : LogOutput.Loggable {
    var includeFile: Bool = false
    var includeTags: [String] = []
    var excludeTags: [String] = []
    func log(_ log: Log) {
        print(log.formatOutput(includeFile: includeFile))
    }
}

class SavedLogOutput : LogOutput.Loggable {
    var includeFile: Bool = false
    var includeTags: [String] = []
    var excludeTags: [String] = []
    var output = ""
    func log(_ log: Log) {
        output += "\(log.formatOutput(includeFile: includeFile))\n"
    }
}

class LogOutput {
    
    protocol Loggable {
        /// Whether to include file origin or not
        var includeFile: Bool { get set }
        /// Empty array means log all regardless of tags
        var includeTags: [String] { get set }
        /// Empty array means don't exclude any tags
        var excludeTags: [String] { get set }
        /// Logging function
        mutating func log(_ log: Log)
    }

    static let instance = LogOutput()
    
    
    // Avoid output thread lock
    private let semaphore = DispatchSemaphore(value: 1)
    private let queue = DispatchQueue.global(qos: .userInitiated)
    
    // Outputs
    private var stdouts: [any Loggable]
    
    private init() {
        let printLog = PrintLogOutput()
        let savedLog = SavedLogOutput()
        stdouts = [printLog, savedLog]
    }
    
    func publish(_ o: Log) {
        runResourceLocked { [self] in
            for var output in stdouts {
                for tag in o.tags {
                    let included = output.includeTags.contains(tag)
                    let excluded = output.excludeTags.contains(tag)
                    let empty = output.includeTags.isEmpty && output.excludeTags.isEmpty
                    if empty || (included && !excluded) {
                        output.log(o)
                        return
                    }
                }
            }
        }
    }

    private func runResourceLocked(fn: @escaping () -> Void) {
        queue.async { [self] in
            semaphore.wait()
            fn()
            semaphore.signal()
        }
    }
    
    func addLoggable(out: any Loggable) {
        runResourceLocked {
            self.stdouts.append(out)
        }
    }
    
    func clearLoggables() {
        runResourceLocked {
            self.stdouts.removeAll()
        }
    }

}

class Log {
    
    static func info(_ msg: String, _ tags: [String] = [], _ file: String = #file) {
        let log = Log(["INFO"] + tags, file, msg)
        LogOutput.instance.publish(log)
    }
    
    static func warn(_ msg: String, _ tags: [String] = [], _ file: String = #file) {
        let log = Log(["WARN"] + tags, file, msg)
        LogOutput.instance.publish(log)
    }
    
    static func error(_ msg: String, _ tags: [String] = [], _ file: String = #file) {
        let log = Log(["ERROR"] + tags, file, msg)
        LogOutput.instance.publish(log)
    }

    let tags: [String]
    let file: String
    let msg: String
    
    private init(_ tags: [String], _ file: String, _ msg: String) {
        self.tags = tags
        self.file = file
        self.msg = msg
    }
    
    func formatOutput(includeFile: Bool) -> String {
        let tagSegment = tags.count == 0 ? "" : " [\(tags.joined(separator: ", "))]"
        let callerSegment = includeFile ? " \(file)" : ""
        return "\(tagSegment)\(callerSegment): \(msg)"
    }

}

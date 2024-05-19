//
//  CountdownTimerView.swift
//  AudioSpectrogram
//
//  Created by Callum MacKenzie on 2024-05-19.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import SwiftUI

struct CountdownTimerView: View {
    @State private var duration = "---"
    private let desiredDuration: Date
        private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(seconds: Int) {
        desiredDuration = Calendar.current.date(byAdding: .second, value: seconds, to: Date())!
    }
        
        static var duratioinFormatter: DateComponentsFormatter = {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .abbreviated
            formatter.zeroFormattingBehavior = .dropLeading
            return formatter
        }()
        
        var body: some View {
            VStack {
                HStack(spacing: 12) {
                    Spacer()
                    Text(duration)
                        .font(.system(size: 18, weight: .bold))
                        .padding()
                        .foregroundStyle(Color.white)
                        .background(Color.gray)
                        .cornerRadius(6)
                    Spacer()
                }
            }
            .frame(width: 300, height: 34)
            .onReceive(timer) { _ in
                var delta = desiredDuration.timeIntervalSince(Date())
                if delta <= 0 {
                    delta = 0
                    timer.upstream.connect().cancel()
                }
                duration = CountdownTimerView.duratioinFormatter.string(from: delta) ?? "---"
            }
        }
    
}

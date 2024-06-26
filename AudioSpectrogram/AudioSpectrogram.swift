/*
 See the LICENSE.txt file for this sample’s licensing information.
 
 Abstract:
 The class that provides a signal that represents a drum loop.
 */

import Accelerate
import Combine
import AVFoundation
import UIKit

class AudioSpectrogram: NSObject, ObservableObject {
    
    private var gain: Double = 0.038
    private var zeroReference: Double = 550
    
    @Published var previewOutputImage = AudioSpectrogram.emptyCGImage
    @Published var fullOutputImage = AudioSpectrogram.emptyCGImage
    @Published var totalRecordingDuration = Duration.zero
    
    // MARK: Initialization
    
    override init() {
        super.init()
        
        configureCaptureSession()
        audioOutput.setSampleBufferDelegate(self, queue: captureQueue)
        
        Log.info("""
                 freq range = \(AudioSpectrogram.frequencyRange), \
                 sample count = \(AudioSpectrogram.sampleCount), \
                 buffer count = \(AudioSpectrogram.bufferCount) , \
                 gain = \(gain), \
                 zero ref = \(zeroReference) \
                 export rate = \(AudioSpectrogram.dataExportRate)
                 """,
                 ["AudioSpectrogram"])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: Properties
    
    /// The number of samples per frame — the height of the spectrogram.
    static let sampleCount = 1024 * 2
    
    /// The number of displayed buffers — the width of the spectrogram.
    static let bufferCount = 768
    
    /// Determines the overlap between frames.
    static let hopCount = (sampleCount + 1) / 2
    
    /// Determines after how many samples to process extra data
    static let dataExportRate = 100
    var bufferCounter = 0
    
    // Though guitar frequencies have harmonics reaching 5 kHz, resolution at lower frequencies
    // is more important for note recognition; harmonic profile not as necessary given we are assuming
    // we are recording guitar. The note e6 is the highest reasonable guitar note at 1300 Hz so we have
    // headroom.
    static let frequencyRange: ClosedRange<Float> = 45 ... 2000
    
    lazy var melSpectrogram = MelSpectrogram(
        filterBankCount: AudioSpectrogram.sampleCount,
        sampleCount: AudioSpectrogram.sampleCount,
        frequencyRange: AudioSpectrogram.frequencyRange)
    
    let captureSession = AVCaptureSession()
    let audioOutput = AVCaptureAudioDataOutput()
    let captureQueue = DispatchQueue(label: "captureQueue",
                                     qos: .userInitiated,
                                     attributes: [],
                                     autoreleaseFrequency: .workItem)
    let sessionQueue = DispatchQueue(label: "sessionQueue",
                                     attributes: [],
                                     autoreleaseFrequency: .workItem)
    
    let forwardDCT = vDSP.DCT(count: sampleCount,
                              transformType: .II)!
    
    /// The window sequence for reducing spectral leakage.
    let hanningWindow = vDSP.window(ofType: Float.self,
                                    usingSequence: .hanningDenormalized,
                                    count: sampleCount,
                                    isHalfWindow: false)
    
    let dispatchSemaphore = DispatchSemaphore(value: 1)
    
    /// For tracking duration of recordings
    var currentRecordingSegmentDuration = Duration.zero
    var lastRecordingStart: Date = Date.now
    
    /// The highest frequency that the app can represent.
    ///
    /// The first call of `AudioSpectrogram.captureOutput(_:didOutput:from:)` calculates
    /// this value.
    var nyquistFrequency: Float?
    
    /// A buffer that contains the raw audio data from AVFoundation.
    var rawAudioData = [Int16]()
    
    /// Raw frequency-domain values.
    var frequencyDomainValues = [Float](repeating: 0,
                                        count: bufferCount * sampleCount)
    
    var frequencyDomainOffset = 0
    
    var rgbImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 32,
        bitsPerPixel: 32 * 3,
        colorSpace: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGBitmapInfo(
            rawValue: kCGBitmapByteOrder32Host.rawValue |
            CGBitmapInfo.floatComponents.rawValue |
            CGImageAlphaInfo.none.rawValue))!
    
    
    /// RGB vImage buffer that contains a vertical representation of the audio spectrogram.
    
    let redBuffer = vImage.PixelBuffer<vImage.PlanarF>(
        width: AudioSpectrogram.sampleCount,
        height: AudioSpectrogram.bufferCount)
    
    let greenBuffer = vImage.PixelBuffer<vImage.PlanarF>(
        width: AudioSpectrogram.sampleCount,
        height: AudioSpectrogram.bufferCount)
    
    let blueBuffer = vImage.PixelBuffer<vImage.PlanarF>(
        width: AudioSpectrogram.sampleCount,
        height: AudioSpectrogram.bufferCount)
    
    var rgbImageBuffer = vImage.PixelBuffer<vImage.InterleavedFx3>(
        width: AudioSpectrogram.sampleCount,
        height: AudioSpectrogram.bufferCount)
    
    
    /// A reusable array that contains the current frame of time-domain audio data as single-precision
    /// values.
    var timeDomainBuffer = [Float](repeating: 0,
                                   count: sampleCount)
    
    /// A resuable array that contains the frequency-domain representation of the current frame of
    /// audio data.
    var frequencyDomainBuffer = [Float](repeating: 0,
                                        count: sampleCount)
    
    // MARK: Instance Methods
    
    /// Process a frame of raw audio data.
    ///
    /// * Convert supplied `Int16` values to single-precision and write the result to `timeDomainBuffer`.
    /// * Apply a Hann window to the audio data in `timeDomainBuffer`.
    /// * Perform a forward discrete cosine transform and write the result to `frequencyDomainBuffer`.
    /// * Convert frequency-domain values in `frequencyDomainBuffer` to decibels and scale by the
    ///     `gain` value.
    /// * Append the values in `frequencyDomainBuffer` to `frequencyDomainValues`.
    func processData(values: [Int16]) {
        vDSP.convertElements(of: values,
                             to: &timeDomainBuffer)
        
        vDSP.multiply(timeDomainBuffer,
                      hanningWindow,
                      result: &timeDomainBuffer)
        
        forwardDCT.transform(timeDomainBuffer,
                             result: &frequencyDomainBuffer)
        
        vDSP.absolute(frequencyDomainBuffer,
                      result: &frequencyDomainBuffer)
        
        melSpectrogram.computeMelSpectrogram(
            values: &frequencyDomainBuffer)
        
        vDSP.convert(power: frequencyDomainBuffer,
                     toDecibels: &frequencyDomainBuffer,
                     zeroReference: Float(zeroReference))
        
        vDSP.multiply(Float(gain),
                      frequencyDomainBuffer,
                      result: &frequencyDomainBuffer)
        
        if frequencyDomainValues.count > AudioSpectrogram.sampleCount {
            frequencyDomainOffset += AudioSpectrogram.sampleCount
            bufferCounter += 1
            if bufferCounter >= AudioSpectrogram.dataExportRate {
                exportData()
                bufferCounter = 0
            }
        }
        
        frequencyDomainValues.append(contentsOf: frequencyDomainBuffer)
        DispatchQueue.main.async {
            self.totalRecordingDuration = self.getRecordingDuration()
        }
    }
    
    func makeSpectrogramImageFromSamples(bufferCount: Int) -> CGImage {
        return frequencyDomainValues.withUnsafeMutableBufferPointer {
            let buffCnt = bufferCount
            let totalBuffs = $0.count / AudioSpectrogram.sampleCount - AudioSpectrogram.bufferCount

            let redBufferLarge = vImage.PixelBuffer<vImage.PlanarF>(
                width: AudioSpectrogram.sampleCount,
                height: buffCnt)
            
            let greenBufferLarge = vImage.PixelBuffer<vImage.PlanarF>(
                width: AudioSpectrogram.sampleCount,
                height: buffCnt)
            
            let blueBufferLarge = vImage.PixelBuffer<vImage.PlanarF>(
                width: AudioSpectrogram.sampleCount,
                height: buffCnt)
            
            let rgbImageBufferLarge = vImage.PixelBuffer<vImage.InterleavedFx3>(
                width: AudioSpectrogram.sampleCount,
                height: buffCnt)
            
            let planarImageBuffer = vImage.PixelBuffer(
                data: $0.baseAddress! + AudioSpectrogram.bufferCount * AudioSpectrogram.sampleCount
                + (totalBuffs - buffCnt) * AudioSpectrogram.sampleCount,
                width: AudioSpectrogram.sampleCount,
                height: buffCnt,
                byteCountPerRow: AudioSpectrogram.sampleCount * MemoryLayout<Float>.stride,
                pixelFormat: vImage.PlanarF.self)
            
            AudioSpectrogram.multidimensionalLookupTable.apply(
                sources: [planarImageBuffer],
                destinations: [redBufferLarge, greenBufferLarge, blueBufferLarge],
                interpolation: .half)
            
            rgbImageBufferLarge.interleave(planarSourceBuffers: [redBufferLarge, greenBufferLarge, blueBufferLarge])
            
            let val = rgbImageBufferLarge.makeCGImage(cgImageFormat: rgbImageFormat) ?? AudioSpectrogram.emptyCGImage
            return val
        }
    }
    
    /// Creates an audio spectrogram `CGImage` from `frequencyDomainValues`.
    func makePreviewAudioSpectrogramImage() -> CGImage {
        
        frequencyDomainValues.withUnsafeMutableBufferPointer {
            let planarImageBuffer = vImage.PixelBuffer(
                data: $0.baseAddress! + frequencyDomainOffset,
                width: AudioSpectrogram.sampleCount,
                height: AudioSpectrogram.bufferCount,
                byteCountPerRow: AudioSpectrogram.sampleCount * MemoryLayout<Float>.stride,
                pixelFormat: vImage.PlanarF.self)
            
            AudioSpectrogram.multidimensionalLookupTable.apply(
                sources: [planarImageBuffer],
                destinations: [redBuffer, greenBuffer, blueBuffer],
                interpolation: .half)
            
        }
        
        rgbImageBuffer.interleave(planarSourceBuffers: [redBuffer, greenBuffer, blueBuffer])
        
        return rgbImageBuffer.makeCGImage(cgImageFormat: rgbImageFormat) ?? AudioSpectrogram.emptyCGImage
    }
    
    func updateFullAudioSpectrogramImage() {
        self.fullOutputImage = makeFullAudioSpectrogramImage()
    }
    
    func makeFullAudioSpectrogramImage() -> CGImage {
        let startDate = Date.now
        if self.totalRecordingDuration == Duration.zero {
            return AudioSpectrogram.emptyCGImage
        }
        let height = frequencyDomainValues.count / AudioSpectrogram.sampleCount - AudioSpectrogram.bufferCount
        let img = makeSpectrogramImageFromSamples(bufferCount: height)
        // Log processing time
        let finishTime = -startDate.timeIntervalSinceNow
        Log.info("Processing time: \(finishTime) s", ["AudioSpectrogram", "Image"])
        return img
    }
    
    func clear() {
        frequencyDomainOffset = 0
        frequencyDomainValues = [Float](repeating: 0,
                                        count: AudioSpectrogram.bufferCount * AudioSpectrogram.sampleCount)
        previewOutputImage = AudioSpectrogram.emptyCGImage
        fullOutputImage = AudioSpectrogram.emptyCGImage
        currentRecordingSegmentDuration = Duration.zero
        totalRecordingDuration = Duration.zero
        bufferCounter = 0
        
        Log.info("Cleared", ["AudioSpectrogram"])
    }
    
    /// Starts and stops the audio spectrogram.
    func setRunning(run: Bool) {
        sessionQueue.async {
            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                if run {
                    DispatchQueue.main.async {
                        self.lastRecordingStart = Date.now
                    }
                    self.captureSession.startRunning()
                    Log.info("Started", ["AudioSpectrogram"])
                } else  {
                    DispatchQueue.main.async {
                        self.currentRecordingSegmentDuration = self.getRecordingDuration()
                        self.updateFullAudioSpectrogramImage()
                    }
                    self.captureSession.stopRunning()
                    Log.info("Stopped", ["AudioSpectrogram"])
                }
            }
        }
    }
    
    /// Returns current elapsed runtime
    func getRecordingDuration() -> Duration {
        if self.captureSession.isRunning {
            let timeIntervalSinceLastRecordingStart = Date.now.timeIntervalSince(self.lastRecordingStart)
            let durationSinceStartOfCurrentRecording = Duration.seconds(timeIntervalSinceLastRecordingStart)
            return self.currentRecordingSegmentDuration + durationSinceStartOfCurrentRecording
        } else {
            return self.currentRecordingSegmentDuration
        }
    }
    
    private func exportData() {
        Log.info("Exporting data ...", ["AudioSpectrogram"])
    }
    
}

// MARK: Utility functions
extension AudioSpectrogram {
    
    /// Returns the RGB values from a blue -> red -> green color map for a specified value.
    ///
    /// Values near zero return dark blue, `0.5` returns red, and `1.0` returns full-brightness green.
    static var multidimensionalLookupTable: vImage.MultidimensionalLookupTable = {
        let entriesPerChannel = UInt8(32)
        let srcChannelCount = 1
        let destChannelCount = 3
        
        let lookupTableElementCount = Int(pow(Float(entriesPerChannel),
                                              Float(srcChannelCount))) *
        Int(destChannelCount)
        
        let tableData = [UInt16](unsafeUninitializedCapacity: lookupTableElementCount) {
            buffer, count in
            
            /// Supply the samples in the range `0...65535`. The transform function
            /// interpolates these to the range `0...1`.
            let multiplier = CGFloat(UInt16.max)
            var bufferIndex = 0
            
            for gray in ( 0 ..< entriesPerChannel) {
                /// Create normalized red, green, and blue values in the range `0...1`.
                let normalizedValue = CGFloat(gray) / CGFloat(entriesPerChannel - 1)
                
                // Define `hue` that's blue at `0.0` to red at `1.0`.
                let hue = 0.6666 - (0.6666 * normalizedValue)
                let brightness = sqrt(normalizedValue)
                
                let color = UIColor(hue: hue,
                                    saturation: 1,
                                    brightness: brightness,
                                    alpha: 1)
                
                var red = CGFloat()
                var green = CGFloat()
                var blue = CGFloat()
                
                color.getRed(&red,
                             green: &green,
                             blue: &blue,
                             alpha: nil)
                
                buffer[ bufferIndex ] = UInt16(green * multiplier)
                bufferIndex += 1
                buffer[ bufferIndex ] = UInt16(red * multiplier)
                bufferIndex += 1
                buffer[ bufferIndex ] = UInt16(blue * multiplier)
                bufferIndex += 1
            }
            
            count = lookupTableElementCount
        }
        
        let entryCountPerSourceChannel = [UInt8](repeating: entriesPerChannel,
                                                 count: srcChannelCount)
        
        return vImage.MultidimensionalLookupTable(entryCountPerSourceChannel: entryCountPerSourceChannel,
                                                  destinationChannelCount: destChannelCount,
                                                  data: tableData)
    }()
    
    /// A 1x1 Core Graphics image.
    static var emptyCGImage: CGImage = {
        let buffer = vImage.PixelBuffer(
            pixelValues: [0],
            size: .init(width: 1, height: 1),
            pixelFormat: vImage.Planar8.self)
        
        let fmt = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 8 ,
            colorSpace: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            renderingIntent: .defaultIntent)
        
        return buffer.makeCGImage(cgImageFormat: fmt!)!
    }()
}

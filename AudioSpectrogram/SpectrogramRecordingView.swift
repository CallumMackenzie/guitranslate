//
//  SpectrogramRecordingView.swift
//  Guitranslate
//
//  Created by Callum MacKenzie on 2024-05-19.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import SwiftUI

struct SpectrogramRecordingView: View {
    
    @EnvironmentObject var audioSpectrogram: AudioSpectrogram
    @State var recording = false
    
    var body: some View {
        Image(decorative: audioSpectrogram.outputImage,
              scale: 1,
              orientation: .left)
        .resizable()
        
        HStack {
            Button(recording ? "Stop Recording" : "Record") {
                recording = !recording
                audioSpectrogram.setRunning(run: recording)
            }
        }
    }
    
}

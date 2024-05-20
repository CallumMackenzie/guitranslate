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
    @State var fullSpectrogramImage = AudioSpectrogram.emptyCGImage
    
    var body: some View {
        
        VStack {
            if (recording) {
                Image(decorative: audioSpectrogram.outputImage,
                      scale: 1,
                      orientation: .left)
                .resizable()
            } else {
                ScrollView(.horizontal) {
                    Image(decorative: fullSpectrogramImage,
                          scale: 1,
                          orientation: .left)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                }.defaultScrollAnchor(.bottom)
            }
        }
        .border(.primary)
        .padding(1)
        .frame(minWidth: 0,
               maxWidth: .infinity,
               minHeight: 0,
               maxHeight: .infinity,
               alignment: .center)
        
        HStack {
            Button(recording ? "Stop Recording" : "Record") {
                recording = !recording
                audioSpectrogram.setRunning(run: recording)
                if (!recording) {
                    fullSpectrogramImage = audioSpectrogram.makeFullAudioSpectrogramImage()
                }
            }
            
            Button("Clear") {
                audioSpectrogram.clear()
                fullSpectrogramImage = AudioSpectrogram.emptyCGImage
            }.disabled(recording)
        }
    }
    
}

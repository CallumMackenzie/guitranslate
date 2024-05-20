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
        
        VStack {
            if (recording) {
                Image(decorative: audioSpectrogram.previewOutputImage,
                      scale: 1,
                      orientation: .left)
                .resizable()
            } else {
                ScrollView(.horizontal) {
                    VStack {
                        Image(decorative: audioSpectrogram.fullOutputImage,
                              scale: 1,
                              orientation: .left)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        TabEditorView()
                    }
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
        
        Text("\(audioSpectrogram.totalRecordingDuration.formatted())")
        
        HStack {
            Button(recording ? "Stop Recording" : "Record") {
                recording = !recording
                audioSpectrogram.setRunning(run: recording)
            }
            
            Button("Clear") {
                audioSpectrogram.clear()
            }.disabled(recording)
        }
    }
    
}

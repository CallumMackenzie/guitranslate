/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The audio spectrogram content view.
*/

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var audioSpectrogram: AudioSpectrogram
    @State var recording = false
    
    var body: some View {
        
        VStack {
            
            Image(decorative: audioSpectrogram.outputImage,
                  scale: 1,
                  orientation: .left)
            .resizable()
            
            HStack {
                Button(recording ? "Stop Recording" : "Record") {
                    recording = !recording
                    audioSpectrogram.setRunning(run: recording)
                }
                Button("Training Mode") {
                    
                }
            }
            
//            HStack {
//                VStack {
//                    Text("Gain")
//                    Slider(value: $audioSpectrogram.gain,
//                           in: 0.01 ... 0.04)
//                    Text("\($audioSpectrogram.gain.wrappedValue)")
//                }
//                Divider().frame(height: 40)
//                
//                VStack {
//                    Text("Zero Ref")
//                    Slider(value: $audioSpectrogram.zeroReference,
//                           in: 10 ... 2500)
//                    Text("\($audioSpectrogram.zeroReference.wrappedValue)")
//                }
//            }
//            .padding()
        }
    }
}

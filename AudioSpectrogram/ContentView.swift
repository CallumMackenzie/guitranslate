/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The audio spectrogram content view.
*/

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var audioSpectrogram: AudioSpectrogram
    @State var training = false
    
    var body: some View {
        
        VStack {
            SpectrogramRecordingView()
                .environmentObject(audioSpectrogram)
            
            HStack {
                Button(training ? "Exit Training Mode" : "Training Mode") {
                    training = !training
                }
            }
        }
    }
}

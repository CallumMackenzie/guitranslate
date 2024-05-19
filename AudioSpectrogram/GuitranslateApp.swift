/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The audio spectrogram app file.
*/
import SwiftUI

@main
struct GuitranslateApp: App {
    
    @Environment(\.scenePhase) private var scenePhase
    
    let audioSpectrogram = AudioSpectrogram()
  
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioSpectrogram)
        }
    }
}

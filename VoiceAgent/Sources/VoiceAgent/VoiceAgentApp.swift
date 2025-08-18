import SwiftUI
import AVFoundation

@main
struct VoiceAgentApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var voiceController = VoiceController()
    @StateObject private var aiManager = AIManager()
    @StateObject private var settingsManager = SettingsManager()
    
    init() {
        // Request microphone permissions on launch
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                print("Microphone access granted")
            } else {
                print("Microphone access denied")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(voiceController)
                .environmentObject(aiManager)
                .environmentObject(settingsManager)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        
        Settings {
            SettingsView()
                .environmentObject(settingsManager)
                .environmentObject(aiManager)
        }
        
        MenuBarExtra("Voice Agent", systemImage: "mic.circle.fill") {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(voiceController)
        }
    }
}
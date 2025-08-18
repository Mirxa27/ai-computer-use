import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var voiceController: VoiceController
    @State private var showQuickInput = false
    @State private var quickInputText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status section
            HStack {
                Image(systemName: "mic.circle.fill")
                    .foregroundColor(voiceController.isListening ? .red : .blue)
                
                Text(voiceController.isListening ? "Listening..." : "Ready")
                    .font(.headline)
                
                Spacer()
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Quick actions
            Group {
                Button(action: toggleListening) {
                    Label(
                        voiceController.isListening ? "Stop Listening" : "Start Listening",
                        systemImage: voiceController.isListening ? "mic.slash" : "mic"
                    )
                }
                .keyboardShortcut("l", modifiers: [.command])
                
                Button(action: { showQuickInput.toggle() }) {
                    Label("Quick Input", systemImage: "text.cursor")
                }
                .keyboardShortcut("i", modifiers: [.command])
                
                if showQuickInput {
                    HStack {
                        TextField("Type a message...", text: $quickInputText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                sendQuickInput()
                            }
                        
                        Button("Send") {
                            sendQuickInput()
                        }
                        .disabled(quickInputText.isEmpty)
                    }
                    .padding(.horizontal)
                }
            }
            
            Divider()
            
            // Provider selection
            Menu {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Button(action: {
                        NotificationCenter.default.post(
                            name: .providerChanged,
                            object: nil,
                            userInfo: ["provider": provider]
                        )
                    }) {
                        HStack {
                            Image(systemName: provider.icon)
                            Text(provider.rawValue)
                            if appState.activeProvider == provider {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: appState.activeProvider.icon)
                    Text("Provider: \(appState.activeProvider.rawValue)")
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .padding(.horizontal)
            
            Divider()
            
            // Recent conversations
            if !appState.conversationHistory.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ForEach(appState.conversationHistory.suffix(3)) { entry in
                        if entry.role == .user {
                            Button(action: {
                                // Re-send this message
                                resendMessage(entry.content)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                    Text(entry.content)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    }
                }
                
                Divider()
            }
            
            // App actions
            Group {
                Button(action: openMainWindow) {
                    Label("Open Main Window", systemImage: "macwindow")
                }
                
                Button(action: openSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: [.command])
                
                Button(action: clearHistory) {
                    Label("Clear History", systemImage: "trash")
                }
                
                Divider()
                
                Button(action: quitApp) {
                    Label("Quit", systemImage: "power")
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
        }
        .frame(width: 300)
    }
    
    private var statusColor: Color {
        switch appState.connectionStatus {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected, .error:
            return .red
        }
    }
    
    private func toggleListening() {
        if voiceController.isListening {
            voiceController.stopListening()
        } else {
            voiceController.startListening()
        }
    }
    
    private func sendQuickInput() {
        guard !quickInputText.isEmpty else { return }
        
        let message = quickInputText
        quickInputText = ""
        showQuickInput = false
        
        // Send to AI manager
        Task {
            let command = VoiceCommand(
                originalText: message,
                normalizedText: message.lowercased(),
                intent: Intent(type: .askQuestion, confidence: 1.0),
                entities: [],
                confidence: 1.0,
                timestamp: Date()
            )
            
            NotificationCenter.default.post(
                name: .voiceCommandReceived,
                object: nil,
                userInfo: ["command": command, "text": message]
            )
        }
    }
    
    private func resendMessage(_ message: String) {
        Task {
            let command = VoiceCommand(
                originalText: message,
                normalizedText: message.lowercased(),
                intent: Intent(type: .askQuestion, confidence: 1.0),
                entities: [],
                confidence: 1.0,
                timestamp: Date()
            )
            
            NotificationCenter.default.post(
                name: .voiceCommandReceived,
                object: nil,
                userInfo: ["command": command, "text": message]
            )
        }
    }
    
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    private func openSettings() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
    
    private func clearHistory() {
        appState.clearHistory()
    }
    
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
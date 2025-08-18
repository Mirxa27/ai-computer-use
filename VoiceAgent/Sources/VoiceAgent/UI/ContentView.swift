import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var voiceController: VoiceController
    @EnvironmentObject var aiManager: AIManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var inputText = ""
    @State private var showSettings = false
    @State private var showContextEditor = false
    @State private var animateWaveform = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(NSColor.controlBackgroundColor),
                    Color(NSColor.windowBackgroundColor)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HeaderView()
                    .environmentObject(appState)
                    .environmentObject(aiManager)
                
                Divider()
                
                // Main content area
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if appState.conversationHistory.isEmpty {
                                EmptyStateView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, 100)
                            } else {
                                ForEach(appState.conversationHistory) { entry in
                                    ConversationEntryView(entry: entry)
                                        .id(entry.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: appState.conversationHistory.count) { _ in
                        withAnimation {
                            proxy.scrollTo(appState.conversationHistory.last?.id, anchor: .bottom)
                        }
                    }
                }
                
                Divider()
                
                // Voice control area
                VoiceControlView()
                    .environmentObject(voiceController)
                    .environmentObject(appState)
                
                // Input area
                InputAreaView(inputText: $inputText)
                    .environmentObject(appState)
                    .environmentObject(aiManager)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settingsManager)
                .environmentObject(aiManager)
        }
        .sheet(isPresented: $showContextEditor) {
            ContextEditorView()
                .environmentObject(aiManager)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { showContextEditor.toggle() }) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .help("Edit Context Parameters")
                }
            }
            
            ToolbarItem(placement: .navigation) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .help("Settings")
                }
            }
        }
        .onAppear {
            setupNotificationObservers()
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .conversationUpdated,
            object: nil,
            queue: .main
        ) { notification in
            if let userEntry = notification.userInfo?["userEntry"] as? ConversationEntry {
                appState.addConversationEntry(userEntry)
            }
            if let assistantEntry = notification.userInfo?["assistantEntry"] as? ConversationEntry {
                appState.addConversationEntry(assistantEntry)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .voiceResponseReady,
            object: nil,
            queue: .main
        ) { notification in
            if let response = notification.userInfo?["response"] as? String {
                voiceController.speak(response)
            }
        }
    }
}

// MARK: - Header View
struct HeaderView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var aiManager: AIManager
    
    var body: some View {
        HStack {
            // App title
            HStack(spacing: 8) {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Voice Agent")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            // Connection status
            ConnectionStatusView()
            
            // Provider selector
            ProviderSelectorView()
                .environmentObject(aiManager)
        }
        .padding()
    }
}

// MARK: - Connection Status View
struct ConnectionStatusView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 2)
                        .scaleEffect(appState.connectionStatus == .connected ? 1.5 : 1.0)
                        .opacity(appState.connectionStatus == .connected ? 0 : 1)
                        .animation(
                            appState.connectionStatus == .connected ?
                            Animation.easeOut(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: appState.connectionStatus
                        )
                )
            
            Text(appState.connectionStatus.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
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
}

// MARK: - Provider Selector View
struct ProviderSelectorView: View {
    @EnvironmentObject var aiManager: AIManager
    @State private var selectedProvider: AIProvider = .openai
    
    var body: some View {
        Menu {
            ForEach(AIProvider.allCases, id: \.self) { provider in
                Button(action: {
                    selectedProvider = provider
                    aiManager.switchProvider(provider)
                }) {
                    HStack {
                        Image(systemName: provider.icon)
                        Text(provider.rawValue)
                        if aiManager.currentProvider?.type == provider {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedProvider.icon)
                Text(selectedProvider.rawValue)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .onAppear {
            selectedProvider = aiManager.currentProvider?.type ?? .openai
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Start a conversation")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Click the microphone or type a message to begin")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
}

// MARK: - Conversation Entry View
struct ConversationEntryView: View {
    let entry: ConversationEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(entry.role == .user ? Color.blue : Color.green)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: entry.role == .user ? "person.fill" : "cpu")
                        .foregroundColor(.white)
                        .font(.system(size: 16))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                // Header
                HStack {
                    Text(entry.role == .user ? "You" : "Assistant")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if let provider = entry.provider {
                        Text("• \(provider.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // Content
                Text(entry.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(entry.role == .user ? 
                          Color.blue.opacity(0.1) : 
                          Color(NSColor.controlBackgroundColor))
            )
        }
        .padding(.horizontal)
    }
}

// MARK: - Voice Control View
struct VoiceControlView: View {
    @EnvironmentObject var voiceController: VoiceController
    @EnvironmentObject var appState: AppState
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Waveform visualization
            WaveformView(audioLevel: voiceController.audioLevel, isActive: voiceController.isListening)
                .frame(height: 60)
                .padding(.horizontal)
            
            // Control buttons
            HStack(spacing: 20) {
                // Microphone button
                Button(action: toggleListening) {
                    ZStack {
                        Circle()
                            .fill(voiceController.isListening ? Color.red : Color.blue)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: voiceController.isListening ? "mic.fill" : "mic")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(isHovering ? 1.1 : 1.0)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3)) {
                        isHovering = hovering
                    }
                }
                
                // Status text
                VStack(alignment: .leading, spacing: 4) {
                    Text(voiceController.recognitionStatus.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !voiceController.transcribedText.isEmpty {
                        Text(voiceController.transcribedText)
                            .font(.body)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Clear button
                Button(action: {
                    appState.clearHistory()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .help("Clear conversation history")
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private func toggleListening() {
        if voiceController.isListening {
            voiceController.stopListening()
        } else {
            voiceController.startListening()
        }
    }
}

// MARK: - Waveform View
struct WaveformView: View {
    let audioLevel: Float
    let isActive: Bool
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, through: width, by: 2) {
                    let relativeX = x / width
                    let sine = sin((relativeX + phase) * .pi * 8)
                    let y = midHeight + (sine * CGFloat(audioLevel) * midHeight * 0.8)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        isActive ? Color.blue : Color.gray,
                        isActive ? Color.purple : Color.gray.opacity(0.5)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Input Area View
struct InputAreaView: View {
    @Binding var inputText: String
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var aiManager: AIManager
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $inputText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.body)
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(20)
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty || isProcessing)
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        
        let message = inputText
        inputText = ""
        isProcessing = true
        
        Task {
            do {
                let response = try await aiManager.processInput(message)
                isProcessing = false
            } catch {
                appState.errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }
}
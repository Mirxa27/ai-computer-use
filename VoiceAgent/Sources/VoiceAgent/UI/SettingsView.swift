import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var aiManager: AIManager
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Reset to Defaults") {
                    settingsManager.resetToDefaults()
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding()
            
            Divider()
            
            // Tab view
            TabView(selection: $selectedTab) {
                GeneralSettingsView()
                    .tabItem {
                        Label("General", systemImage: "gearshape")
                    }
                    .tag(0)
                
                VoiceSettingsView()
                    .tabItem {
                        Label("Voice", systemImage: "mic")
                    }
                    .tag(1)
                
                AISettingsView()
                    .environmentObject(aiManager)
                    .tabItem {
                        Label("AI Providers", systemImage: "brain")
                    }
                    .tag(2)
                
                ContextSettingsView()
                    .environmentObject(aiManager)
                    .tabItem {
                        Label("Context", systemImage: "doc.text")
                    }
                    .tag(3)
                
                AppearanceSettingsView()
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    .tag(4)
            }
            .padding()
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - General Settings View
struct GeneralSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at startup", isOn: $settingsManager.generalSettings.launchAtStartup)
                Toggle("Show in menu bar", isOn: $settingsManager.generalSettings.showInMenuBar)
                Toggle("Show in dock", isOn: $settingsManager.generalSettings.showInDock)
            }
            
            Section("Behavior") {
                Toggle("Auto-minimize after response", isOn: $settingsManager.generalSettings.autoMinimize)
                Toggle("Enable notifications", isOn: $settingsManager.generalSettings.notificationsEnabled)
                
                HStack {
                    Text("Global hotkey:")
                    TextField("Hotkey", text: $settingsManager.generalSettings.globalHotkey)
                        .frame(width: 150)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Voice Settings View
struct VoiceSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var availableVoices: [String] = []
    
    var body: some View {
        Form {
            Section("Audio Devices") {
                Picker("Input device:", selection: $settingsManager.voiceSettings.inputDevice) {
                    Text("Default").tag("Default")
                    // Add available input devices
                }
                
                Picker("Output device:", selection: $settingsManager.voiceSettings.outputDevice) {
                    Text("Default").tag("Default")
                    // Add available output devices
                }
            }
            
            Section("Voice Activation") {
                Toggle("Voice activation enabled", isOn: $settingsManager.voiceSettings.voiceActivationEnabled)
                
                if !settingsManager.voiceSettings.voiceActivationEnabled {
                    HStack {
                        Text("Push-to-talk key:")
                        TextField("Key", text: $settingsManager.voiceSettings.pushToTalkKey)
                            .frame(width: 100)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Voice activity threshold: \(settingsManager.voiceSettings.voiceActivityThreshold, specifier: "%.2f")")
                    Slider(value: $settingsManager.voiceSettings.voiceActivityThreshold, in: 0...1)
                }
                
                VStack(alignment: .leading) {
                    Text("Silence detection delay: \(settingsManager.voiceSettings.silenceDetectionDelay, specifier: "%.1f")s")
                    Slider(value: $settingsManager.voiceSettings.silenceDetectionDelay, in: 0.5...5.0)
                }
            }
            
            Section("Speech Synthesis") {
                Picker("Voice:", selection: $settingsManager.voiceSettings.selectedVoice) {
                    ForEach(availableVoices, id: \.self) { voice in
                        Text(voice).tag(voice)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Speech rate: \(settingsManager.voiceSettings.speechRate, specifier: "%.2f")")
                    Slider(value: $settingsManager.voiceSettings.speechRate, in: 0.1...1.0)
                }
                
                VStack(alignment: .leading) {
                    Text("Pitch: \(settingsManager.voiceSettings.speechPitch, specifier: "%.2f")")
                    Slider(value: $settingsManager.voiceSettings.speechPitch, in: 0.5...2.0)
                }
                
                VStack(alignment: .leading) {
                    Text("Volume: \(settingsManager.voiceSettings.speechVolume, specifier: "%.2f")")
                    Slider(value: $settingsManager.voiceSettings.speechVolume, in: 0...1)
                }
            }
            
            Section("Recognition") {
                Picker("Language:", selection: $settingsManager.voiceSettings.transcriptionLanguage) {
                    Text("English (US)").tag("en-US")
                    Text("English (UK)").tag("en-GB")
                    Text("Spanish").tag("es-ES")
                    Text("French").tag("fr-FR")
                    Text("German").tag("de-DE")
                    Text("Italian").tag("it-IT")
                    Text("Japanese").tag("ja-JP")
                    Text("Chinese").tag("zh-CN")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadAvailableVoices()
        }
    }
    
    private func loadAvailableVoices() {
        // Load available system voices
        availableVoices = ["com.apple.speech.synthesis.voice.samantha",
                          "com.apple.speech.synthesis.voice.alex",
                          "com.apple.speech.synthesis.voice.victoria"]
    }
}

// MARK: - AI Settings View
struct AISettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var aiManager: AIManager
    @State private var selectedProvider: AIProvider = .openai
    @State private var apiKey = ""
    @State private var endpoint = ""
    @State private var model = ""
    
    var body: some View {
        Form {
            Section("Default Provider") {
                Picker("Default AI provider:", selection: $settingsManager.aiSettings.defaultProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        HStack {
                            Image(systemName: provider.icon)
                            Text(provider.rawValue)
                        }
                        .tag(provider)
                    }
                }
                
                Toggle("Auto-switch provider on failure", isOn: $settingsManager.aiSettings.autoSwitchProvider)
            }
            
            Section("Provider Configuration") {
                Picker("Configure provider:", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                switch selectedProvider {
                case .openai:
                    OpenAIConfigView()
                case .gemini:
                    GeminiConfigView()
                case .local:
                    LocalModelConfigView()
                }
            }
            
            Section("Advanced") {
                Toggle("Stream responses", isOn: $settingsManager.aiSettings.streamResponses)
                Toggle("Cache responses", isOn: $settingsManager.aiSettings.cacheResponses)
                
                Stepper("Max retries: \(settingsManager.aiSettings.maxRetries)",
                       value: $settingsManager.aiSettings.maxRetries,
                       in: 0...10)
                
                VStack(alignment: .leading) {
                    Text("Timeout: \(settingsManager.aiSettings.timeout, specifier: "%.0f")s")
                    Slider(value: $settingsManager.aiSettings.timeout, in: 10...120)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Provider Configuration Views
struct OpenAIConfigView: View {
    @State private var apiKey = ""
    @State private var model = "gpt-4-turbo-preview"
    @State private var showApiKey = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("API Key:")
                if showApiKey {
                    TextField("sk-...", text: $apiKey)
                } else {
                    SecureField("sk-...", text: $apiKey)
                }
                Button(action: { showApiKey.toggle() }) {
                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
            }
            
            Picker("Model:", selection: $model) {
                Text("GPT-4 Turbo").tag("gpt-4-turbo-preview")
                Text("GPT-4").tag("gpt-4")
                Text("GPT-3.5 Turbo").tag("gpt-3.5-turbo")
            }
            
            Button("Save Configuration") {
                saveConfiguration()
            }
        }
        .onAppear {
            loadConfiguration()
        }
    }
    
    private func loadConfiguration() {
        apiKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
        model = UserDefaults.standard.string(forKey: "openai_model") ?? "gpt-4-turbo-preview"
    }
    
    private func saveConfiguration() {
        UserDefaults.standard.set(apiKey, forKey: "openai_api_key")
        UserDefaults.standard.set(model, forKey: "openai_model")
    }
}

struct GeminiConfigView: View {
    @State private var apiKey = ""
    @State private var model = "gemini-pro"
    @State private var showApiKey = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("API Key:")
                if showApiKey {
                    TextField("API Key", text: $apiKey)
                } else {
                    SecureField("API Key", text: $apiKey)
                }
                Button(action: { showApiKey.toggle() }) {
                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.plain)
            }
            
            Picker("Model:", selection: $model) {
                Text("Gemini Pro").tag("gemini-pro")
                Text("Gemini Pro Vision").tag("gemini-pro-vision")
            }
            
            Button("Save Configuration") {
                saveConfiguration()
            }
        }
        .onAppear {
            loadConfiguration()
        }
    }
    
    private func loadConfiguration() {
        apiKey = UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        model = UserDefaults.standard.string(forKey: "gemini_model") ?? "gemini-pro"
    }
    
    private func saveConfiguration() {
        UserDefaults.standard.set(apiKey, forKey: "gemini_api_key")
        UserDefaults.standard.set(model, forKey: "gemini_model")
    }
}

struct LocalModelConfigView: View {
    @State private var endpoint = "http://localhost:11434"
    @State private var model = "llama2"
    @State private var availableModels: [String] = []
    @State private var isTestingConnection = false
    @State private var connectionStatus = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Endpoint:")
                TextField("http://localhost:11434", text: $endpoint)
            }
            
            HStack {
                Picker("Model:", selection: $model) {
                    ForEach(availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                
                Button("Refresh") {
                    discoverModels()
                }
            }
            
            HStack {
                Button("Test Connection") {
                    testConnection()
                }
                
                if !connectionStatus.isEmpty {
                    Text(connectionStatus)
                        .font(.caption)
                        .foregroundColor(connectionStatus.contains("Success") ? .green : .red)
                }
            }
            
            Button("Save Configuration") {
                saveConfiguration()
            }
        }
        .onAppear {
            loadConfiguration()
            discoverModels()
        }
    }
    
    private func loadConfiguration() {
        endpoint = UserDefaults.standard.string(forKey: "local_model_endpoint") ?? "http://localhost:11434"
        model = UserDefaults.standard.string(forKey: "local_model_name") ?? "llama2"
    }
    
    private func saveConfiguration() {
        UserDefaults.standard.set(endpoint, forKey: "local_model_endpoint")
        UserDefaults.standard.set(model, forKey: "local_model_name")
    }
    
    private func discoverModels() {
        // Implement model discovery
        availableModels = ["llama2", "codellama", "mistral", "mixtral"]
    }
    
    private func testConnection() {
        isTestingConnection = true
        connectionStatus = "Testing..."
        
        // Implement connection test
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            connectionStatus = "Success: Connected to local model"
            isTestingConnection = false
        }
    }
}

// MARK: - Context Settings View
struct ContextSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var aiManager: AIManager
    
    var body: some View {
        Form {
            Section("Model Context Protocol") {
                Toggle("Enable MCP", isOn: $settingsManager.contextSettings.enableMCP)
                
                Stepper("Max history size: \(settingsManager.contextSettings.maxHistorySize)",
                       value: $settingsManager.contextSettings.maxHistorySize,
                       in: 10...500, step: 10)
                
                Stepper("Context window: \(settingsManager.contextSettings.contextWindowSize)",
                       value: $settingsManager.contextSettings.contextWindowSize,
                       in: 1...20)
                
                Toggle("Auto-save context", isOn: $settingsManager.contextSettings.autoSaveContext)
            }
            
            Section("Context Profiles") {
                List {
                    ForEach(settingsManager.contextSettings.contextProfiles) { profile in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(.headline)
                                Text(profile.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if profile.isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Button("Add Profile") {
                    // Add new profile
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance Settings View
struct AppearanceSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme:", selection: $settingsManager.appearanceSettings.theme) {
                    ForEach(AppearanceSettings.Theme.allCases, id: \.self) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                ColorPicker("Accent color:", selection: .constant(.blue))
            }
            
            Section("Typography") {
                VStack(alignment: .leading) {
                    Text("Font size: \(settingsManager.appearanceSettings.fontSize, specifier: "%.0f")pt")
                    Slider(value: $settingsManager.appearanceSettings.fontSize, in: 10...20)
                }
                
                Picker("Font family:", selection: $settingsManager.appearanceSettings.fontFamily) {
                    Text("SF Pro").tag("SF Pro")
                    Text("Helvetica").tag("Helvetica")
                    Text("Monaco").tag("Monaco")
                }
            }
            
            Section("Window") {
                VStack(alignment: .leading) {
                    Text("Window opacity: \(settingsManager.appearanceSettings.windowOpacity, specifier: "%.0f")%")
                    Slider(value: $settingsManager.appearanceSettings.windowOpacity, in: 0.5...1.0)
                }
                
                Toggle("Show animations", isOn: $settingsManager.appearanceSettings.showAnimations)
                Toggle("Compact mode", isOn: $settingsManager.appearanceSettings.compactMode)
            }
        }
        .formStyle(.grouped)
    }
}
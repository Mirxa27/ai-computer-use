import Foundation
import Combine

/// Manages application settings and preferences
@MainActor
class SettingsManager: ObservableObject {
    @Published var generalSettings: GeneralSettings
    @Published var voiceSettings: VoiceSettings
    @Published var aiSettings: AISettings
    @Published var contextSettings: ContextSettings
    @Published var appearanceSettings: AppearanceSettings
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load settings from UserDefaults
        self.generalSettings = GeneralSettings.load()
        self.voiceSettings = VoiceSettings.load()
        self.aiSettings = AISettings.load()
        self.contextSettings = ContextSettings.load()
        self.appearanceSettings = AppearanceSettings.load()
        
        setupAutoSave()
    }
    
    private func setupAutoSave() {
        // Auto-save settings when they change
        $generalSettings
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { settings in
                settings.save()
            }
            .store(in: &cancellables)
        
        $voiceSettings
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { settings in
                settings.save()
            }
            .store(in: &cancellables)
        
        $aiSettings
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { settings in
                settings.save()
            }
            .store(in: &cancellables)
        
        $contextSettings
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { settings in
                settings.save()
            }
            .store(in: &cancellables)
        
        $appearanceSettings
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { settings in
                settings.save()
            }
            .store(in: &cancellables)
    }
    
    func resetToDefaults() {
        generalSettings = GeneralSettings()
        voiceSettings = VoiceSettings()
        aiSettings = AISettings()
        contextSettings = ContextSettings()
        appearanceSettings = AppearanceSettings()
        
        // Save defaults
        generalSettings.save()
        voiceSettings.save()
        aiSettings.save()
        contextSettings.save()
        appearanceSettings.save()
    }
    
    func exportSettings() -> Data? {
        let settings = ExportableSettings(
            general: generalSettings,
            voice: voiceSettings,
            ai: aiSettings,
            context: contextSettings,
            appearance: appearanceSettings
        )
        
        return try? JSONEncoder().encode(settings)
    }
    
    func importSettings(from data: Data) throws {
        let settings = try JSONDecoder().decode(ExportableSettings.self, from: data)
        
        generalSettings = settings.general
        voiceSettings = settings.voice
        aiSettings = settings.ai
        contextSettings = settings.context
        appearanceSettings = settings.appearance
        
        // Save imported settings
        generalSettings.save()
        voiceSettings.save()
        aiSettings.save()
        contextSettings.save()
        appearanceSettings.save()
    }
}

// MARK: - Settings Models

struct GeneralSettings: Codable {
    var launchAtStartup: Bool = false
    var showInMenuBar: Bool = true
    var showInDock: Bool = true
    var globalHotkey: String = "cmd+shift+space"
    var autoMinimize: Bool = true
    var notificationsEnabled: Bool = true
    
    static func load() -> GeneralSettings {
        guard let data = UserDefaults.standard.data(forKey: "generalSettings"),
              let settings = try? JSONDecoder().decode(GeneralSettings.self, from: data) else {
            return GeneralSettings()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "generalSettings")
        }
    }
}

struct VoiceSettings: Codable {
    var inputDevice: String = "Default"
    var outputDevice: String = "Default"
    var voiceActivationEnabled: Bool = true
    var pushToTalkKey: String = "space"
    var voiceActivityThreshold: Float = 0.3
    var silenceDetectionDelay: Double = 2.0
    var speechRate: Float = 0.5
    var speechPitch: Float = 1.0
    var speechVolume: Float = 0.9
    var selectedVoice: String = "com.apple.speech.synthesis.voice.samantha"
    var transcriptionLanguage: String = "en-US"
    
    static func load() -> VoiceSettings {
        guard let data = UserDefaults.standard.data(forKey: "voiceSettings"),
              let settings = try? JSONDecoder().decode(VoiceSettings.self, from: data) else {
            return VoiceSettings()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "voiceSettings")
        }
    }
}

struct AISettings: Codable {
    var defaultProvider: AIProvider = .openai
    var autoSwitchProvider: Bool = false
    var providerConfigs: [AIProvider: ProviderSettings] = [:]
    var streamResponses: Bool = true
    var cacheResponses: Bool = true
    var maxRetries: Int = 3
    var timeout: Double = 30.0
    
    static func load() -> AISettings {
        guard let data = UserDefaults.standard.data(forKey: "aiSettings"),
              let settings = try? JSONDecoder().decode(AISettings.self, from: data) else {
            return AISettings()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "aiSettings")
        }
    }
}

struct ContextSettings: Codable {
    var enableMCP: Bool = true
    var contextParameters: [ContextParameter] = []
    var maxHistorySize: Int = 100
    var contextWindowSize: Int = 5
    var autoSaveContext: Bool = true
    var contextProfiles: [ContextProfile] = []
    
    static func load() -> ContextSettings {
        guard let data = UserDefaults.standard.data(forKey: "contextSettings"),
              let settings = try? JSONDecoder().decode(ContextSettings.self, from: data) else {
            return ContextSettings()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "contextSettings")
        }
    }
}

struct AppearanceSettings: Codable {
    var theme: Theme = .system
    var accentColor: String = "blue"
    var fontSize: Double = 14
    var fontFamily: String = "SF Pro"
    var windowOpacity: Double = 0.95
    var showAnimations: Bool = true
    var compactMode: Bool = false
    
    enum Theme: String, Codable, CaseIterable {
        case light = "Light"
        case dark = "Dark"
        case system = "System"
    }
    
    static func load() -> AppearanceSettings {
        guard let data = UserDefaults.standard.data(forKey: "appearanceSettings"),
              let settings = try? JSONDecoder().decode(AppearanceSettings.self, from: data) else {
            return AppearanceSettings()
        }
        return settings
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "appearanceSettings")
        }
    }
}

// MARK: - Context Profile

struct ContextProfile: Identifiable, Codable {
    let id = UUID()
    var name: String
    var description: String
    var parameters: [ContextParameter]
    var isActive: Bool = false
    var createdAt: Date = Date()
    var lastUsed: Date?
}

// MARK: - Exportable Settings

struct ExportableSettings: Codable {
    let general: GeneralSettings
    let voice: VoiceSettings
    let ai: AISettings
    let context: ContextSettings
    let appearance: AppearanceSettings
    let exportDate: Date = Date()
    let appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
}
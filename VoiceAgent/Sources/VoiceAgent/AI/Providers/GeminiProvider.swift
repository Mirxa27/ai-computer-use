import Foundation
import GoogleGenerativeAI

/// Gemini AI Provider implementation
class GeminiProvider: AIProviderProtocol {
    var type: AIProvider { .gemini }
    
    private var model: GenerativeModel?
    private var settings: ProviderSettings?
    
    var isConfigured: Bool {
        model != nil && settings?.apiKey != nil
    }
    
    init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        // Load from UserDefaults or Keychain
        if let apiKey = UserDefaults.standard.string(forKey: "gemini_api_key") {
            settings = ProviderSettings(
                apiKey: apiKey,
                model: UserDefaults.standard.string(forKey: "gemini_model") ?? "gemini-pro",
                maxTokens: 2048,
                temperature: 0.7
            )
            
            configureModel(apiKey: apiKey)
        }
    }
    
    private func configureModel(apiKey: String) {
        let modelName = settings?.model ?? "gemini-pro"
        
        let generationConfig = GenerationConfig(
            temperature: Float(settings?.temperature ?? 0.7),
            topP: 0.95,
            topK: 40,
            maxOutputTokens: settings?.maxTokens ?? 2048
        )
        
        model = GenerativeModel(
            name: modelName,
            apiKey: apiKey,
            generationConfig: generationConfig,
            safetySettings: [
                SafetySetting(harmCategory: .harassment, threshold: .blockMediumAndAbove),
                SafetySetting(harmCategory: .hateSpeech, threshold: .blockMediumAndAbove),
                SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockMediumAndAbove),
                SafetySetting(harmCategory: .dangerousContent, threshold: .blockMediumAndAbove)
            ]
        )
    }
    
    func configure(with settings: ProviderSettings) throws {
        guard let apiKey = settings.apiKey, !apiKey.isEmpty else {
            throw AIError.apiKeyMissing
        }
        
        self.settings = settings
        configureModel(apiKey: apiKey)
        
        // Save to UserDefaults
        UserDefaults.standard.set(apiKey, forKey: "gemini_api_key")
        UserDefaults.standard.set(settings.model ?? "gemini-pro", forKey: "gemini_model")
    }
    
    func validateConfiguration() -> Bool {
        return isConfigured
    }
    
    func generateResponse(_ input: EnhancedInput) async throws -> String {
        guard let model = model else {
            throw AIError.providerNotConfigured
        }
        
        do {
            // Build conversation history
            var chatHistory: [ModelContent] = []
            
            // Add system context as first user message if present
            if !input.enrichedPrompt.isEmpty {
                chatHistory.append(ModelContent(role: "user", parts: [.text(input.enrichedPrompt)]))
                chatHistory.append(ModelContent(role: "model", parts: [.text("Understood. I'll follow these instructions.")]))
            }
            
            // Add conversation history
            for entry in input.relevantHistory {
                let role = entry.role == .user ? "user" : "model"
                chatHistory.append(ModelContent(role: role, parts: [.text(entry.content)]))
            }
            
            // Start chat session
            let chat = model.startChat(history: chatHistory)
            
            // Send current message
            let response = try await chat.sendMessage(input.originalInput)
            
            guard let text = response.text else {
                throw AIError.invalidResponse
            }
            
            return text
        } catch {
            if error.localizedDescription.contains("quota") || error.localizedDescription.contains("rate") {
                throw AIError.rateLimitExceeded
            } else {
                throw AIError.networkError(error.localizedDescription)
            }
        }
    }
}
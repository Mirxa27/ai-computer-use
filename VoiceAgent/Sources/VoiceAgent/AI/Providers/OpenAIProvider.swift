import Foundation
import OpenAI

/// OpenAI Provider implementation
class OpenAIProvider: AIProviderProtocol {
    var type: AIProvider { .openai }
    
    private var client: OpenAI?
    private var settings: ProviderSettings?
    
    var isConfigured: Bool {
        client != nil && settings?.apiKey != nil
    }
    
    init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        // Load from UserDefaults or Keychain
        if let apiKey = UserDefaults.standard.string(forKey: "openai_api_key") {
            settings = ProviderSettings(
                apiKey: apiKey,
                model: UserDefaults.standard.string(forKey: "openai_model") ?? "gpt-4-turbo-preview",
                maxTokens: 2048,
                temperature: 0.7
            )
            
            client = OpenAI(apiToken: apiKey)
        }
    }
    
    func configure(with settings: ProviderSettings) throws {
        guard let apiKey = settings.apiKey, !apiKey.isEmpty else {
            throw AIError.apiKeyMissing
        }
        
        self.settings = settings
        self.client = OpenAI(apiToken: apiKey)
        
        // Save to UserDefaults
        UserDefaults.standard.set(apiKey, forKey: "openai_api_key")
        UserDefaults.standard.set(settings.model ?? "gpt-4-turbo-preview", forKey: "openai_model")
    }
    
    func validateConfiguration() -> Bool {
        return isConfigured
    }
    
    func generateResponse(_ input: EnhancedInput) async throws -> String {
        guard let client = client else {
            throw AIError.providerNotConfigured
        }
        
        let messages: [Chat] = buildMessages(from: input)
        
        let query = ChatQuery(
            model: settings?.model ?? "gpt-4-turbo-preview",
            messages: messages,
            temperature: settings?.temperature ?? input.contextMetadata["temperature"] as? Double ?? 0.7,
            maxTokens: settings?.maxTokens ?? input.contextMetadata["maxTokens"] as? Int ?? 2048
        )
        
        do {
            let result = try await client.chats(query: query)
            
            guard let content = result.choices.first?.message.content else {
                throw AIError.invalidResponse
            }
            
            return content
        } catch {
            if error.localizedDescription.contains("rate") {
                throw AIError.rateLimitExceeded
            } else {
                throw AIError.networkError(error.localizedDescription)
            }
        }
    }
    
    private func buildMessages(from input: EnhancedInput) -> [Chat] {
        var messages: [Chat] = []
        
        // Add system message if present
        if !input.enrichedPrompt.isEmpty {
            messages.append(Chat(role: .system, content: input.enrichedPrompt))
        }
        
        // Add conversation history
        for entry in input.relevantHistory {
            let role: Chat.Role = entry.role == .user ? .user : .assistant
            messages.append(Chat(role: role, content: entry.content))
        }
        
        // Add current user input
        messages.append(Chat(role: .user, content: input.originalInput))
        
        return messages
    }
}
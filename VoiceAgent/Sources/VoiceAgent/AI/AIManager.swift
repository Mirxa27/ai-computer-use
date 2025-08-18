import Foundation
import Combine

/// Main AI Manager that coordinates between different AI providers
@MainActor
class AIManager: ObservableObject {
    @Published var currentProvider: AIProviderProtocol?
    @Published var availableProviders: [AIProvider] = AIProvider.allCases
    @Published var isProcessing = false
    @Published var lastResponse: String?
    @Published var error: AIError?
    
    private let mcp = StandardMCP()
    private var providers: [AIProvider: AIProviderProtocol] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupProviders()
        setupObservers()
    }
    
    private func setupProviders() {
        // Initialize providers based on configuration
        providers[.openai] = OpenAIProvider()
        providers[.gemini] = GeminiProvider()
        providers[.local] = LocalModelProvider()
        
        // Set default provider
        currentProvider = providers[.openai]
    }
    
    private func setupObservers() {
        // Listen for voice commands
        NotificationCenter.default.publisher(for: .voiceCommandReceived)
            .compactMap { $0.userInfo?["command"] as? VoiceCommand }
            .sink { [weak self] command in
                Task {
                    await self?.handleVoiceCommand(command)
                }
            }
            .store(in: &cancellables)
    }
    
    func switchProvider(_ provider: AIProvider) {
        currentProvider = providers[provider]
    }
    
    func processInput(_ input: String) async throws -> String {
        guard let provider = currentProvider else {
            throw AIError.noProviderSelected
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // Build enhanced input using MCP
        let enhancedInput = mcp.buildContext(for: input)
        
        do {
            // Send to provider
            let response = try await provider.generateResponse(enhancedInput)
            
            // Apply contextual filters
            let filteredResponse = mcp.applyContextualFilters(response)
            
            lastResponse = filteredResponse
            
            // Store in conversation history
            let userEntry = ConversationEntry(
                timestamp: Date(),
                role: .user,
                content: input,
                provider: nil
            )
            
            let assistantEntry = ConversationEntry(
                timestamp: Date(),
                role: .assistant,
                content: filteredResponse,
                provider: provider.type
            )
            
            NotificationCenter.default.post(
                name: .conversationUpdated,
                object: nil,
                userInfo: [
                    "userEntry": userEntry,
                    "assistantEntry": assistantEntry
                ]
            )
            
            return filteredResponse
        } catch {
            self.error = error as? AIError ?? .unknown(error.localizedDescription)
            throw error
        }
    }
    
    private func handleVoiceCommand(_ command: VoiceCommand) async {
        switch command.intent.type {
        case .askQuestion, .generateContent, .analyze:
            do {
                let response = try await processInput(command.originalText)
                
                // Send response to voice output
                NotificationCenter.default.post(
                    name: .voiceResponseReady,
                    object: nil,
                    userInfo: ["response": response]
                )
            } catch {
                print("Error processing command: \(error)")
            }
            
        case .changeProvider:
            if let providerEntity = command.entities.first(where: { $0.type == .provider }) {
                handleProviderChange(providerEntity.value)
            }
            
        case .adjustSettings:
            if let settingEntity = command.entities.first(where: { $0.type == .setting }) {
                handleSettingAdjustment(settingEntity.value, command: command)
            }
            
        case .clearContext:
            mcp.contextParameters.removeAll()
            
        default:
            break
        }
    }
    
    private func handleProviderChange(_ providerName: String) {
        let normalizedName = providerName.lowercased()
        
        if normalizedName.contains("openai") || normalizedName.contains("gpt") {
            switchProvider(.openai)
        } else if normalizedName.contains("gemini") {
            switchProvider(.gemini)
        } else if normalizedName.contains("local") || normalizedName.contains("llama") {
            switchProvider(.local)
        }
    }
    
    private func handleSettingAdjustment(_ setting: String, command: VoiceCommand) {
        let numbers = command.entities.filter { $0.type == .number }
        
        switch setting.lowercased() {
        case "temperature":
            if let number = numbers.first,
               let value = Double(number.value) {
                mcp.temperature = min(2.0, max(0.0, value))
            }
            
        case "tokens":
            if let number = numbers.first,
               let value = Int(number.value) {
                mcp.maxTokens = min(4096, max(100, value))
            }
            
        default:
            break
        }
    }
    
    func updateContextParameter(_ parameter: ContextParameter) {
        if let index = mcp.contextParameters.firstIndex(where: { $0.id == parameter.id }) {
            mcp.contextParameters[index] = parameter
        } else {
            mcp.contextParameters.append(parameter)
        }
    }
    
    func removeContextParameter(_ id: UUID) {
        mcp.contextParameters.removeAll { $0.id == id }
    }
    
    func getContextParameters() -> [ContextParameter] {
        return mcp.contextParameters
    }
}

// MARK: - AI Provider Protocol

protocol AIProviderProtocol {
    var type: AIProvider { get }
    var isConfigured: Bool { get }
    
    func generateResponse(_ input: EnhancedInput) async throws -> String
    func configure(with settings: ProviderSettings) throws
    func validateConfiguration() -> Bool
}

// MARK: - Provider Settings

struct ProviderSettings: Codable {
    var apiKey: String?
    var endpoint: String?
    var model: String?
    var maxTokens: Int?
    var temperature: Double?
    var additionalParams: [String: String]?
}

// MARK: - AI Errors

enum AIError: LocalizedError {
    case noProviderSelected
    case providerNotConfigured
    case apiKeyMissing
    case networkError(String)
    case invalidResponse
    case rateLimitExceeded
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noProviderSelected:
            return "No AI provider selected"
        case .providerNotConfigured:
            return "Provider not configured"
        case .apiKeyMissing:
            return "API key missing"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from AI provider"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let conversationUpdated = Notification.Name("conversationUpdated")
    static let providerChanged = Notification.Name("providerChanged")
}
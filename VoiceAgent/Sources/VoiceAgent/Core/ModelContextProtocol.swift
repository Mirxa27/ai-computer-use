import Foundation
import Combine

/// Model Context Protocol (MCP) for enhanced AI input efficiency
protocol ModelContextProtocol {
    var contextParameters: [ContextParameter] { get set }
    var systemPrompt: String { get }
    var maxTokens: Int { get set }
    var temperature: Double { get set }
    
    func buildContext(for input: String) -> EnhancedInput
    func applyContextualFilters(_ response: String) -> String
}

/// Enhanced input with contextual parameters
struct EnhancedInput {
    let originalInput: String
    let enrichedPrompt: String
    let contextMetadata: [String: Any]
    let relevantHistory: [ConversationEntry]
    let activeFilters: [ContextFilter]
}

/// Contextual parameter for MCP
struct ContextParameter: Identifiable, Codable {
    let id = UUID()
    var name: String
    var value: String
    var type: ParameterType
    var isActive: Bool = true
    var priority: Int = 0
    
    enum ParameterType: String, Codable, CaseIterable {
        case systemBehavior = "System Behavior"
        case domainKnowledge = "Domain Knowledge"
        case responseStyle = "Response Style"
        case memoryContext = "Memory Context"
        case taskSpecific = "Task Specific"
        case userPreference = "User Preference"
    }
}

/// Context filter for response processing
struct ContextFilter: Identifiable, Codable {
    let id = UUID()
    var name: String
    var filterType: FilterType
    var pattern: String?
    var isActive: Bool = true
    
    enum FilterType: String, Codable, CaseIterable {
        case contentModeration = "Content Moderation"
        case formatEnforcement = "Format Enforcement"
        case lengthControl = "Length Control"
        case topicRelevance = "Topic Relevance"
        case customRegex = "Custom Regex"
    }
}

/// Default MCP implementation
class StandardMCP: ModelContextProtocol, ObservableObject {
    @Published var contextParameters: [ContextParameter] = []
    @Published var maxTokens: Int = 2048
    @Published var temperature: Double = 0.7
    
    private let conversationMemory: ConversationMemory
    
    var systemPrompt: String {
        buildSystemPrompt()
    }
    
    init() {
        self.conversationMemory = ConversationMemory()
        setupDefaultParameters()
    }
    
    private func setupDefaultParameters() {
        contextParameters = [
            ContextParameter(
                name: "Assistant Personality",
                value: "You are a helpful, professional, and friendly AI assistant with expertise in various domains.",
                type: .systemBehavior,
                priority: 10
            ),
            ContextParameter(
                name: "Response Format",
                value: "Provide clear, concise, and well-structured responses. Use markdown formatting when appropriate.",
                type: .responseStyle,
                priority: 8
            ),
            ContextParameter(
                name: "Context Awareness",
                value: "Maintain awareness of the conversation history and refer to previous interactions when relevant.",
                type: .memoryContext,
                priority: 7
            ),
            ContextParameter(
                name: "Voice Optimization",
                value: "Optimize responses for voice output - use natural language, avoid complex formatting, and keep sentences conversational.",
                type: .responseStyle,
                priority: 9
            )
        ]
    }
    
    private func buildSystemPrompt() -> String {
        let activeParams = contextParameters
            .filter { $0.isActive }
            .sorted { $0.priority > $1.priority }
        
        var prompt = "System Configuration:\n\n"
        
        for param in activeParams {
            prompt += "[\(param.type.rawValue)]: \(param.value)\n\n"
        }
        
        return prompt
    }
    
    func buildContext(for input: String) -> EnhancedInput {
        let relevantHistory = conversationMemory.getRelevantHistory(for: input, limit: 5)
        
        var enrichedPrompt = systemPrompt + "\n\n"
        
        if !relevantHistory.isEmpty {
            enrichedPrompt += "Conversation Context:\n"
            for entry in relevantHistory {
                enrichedPrompt += "\(entry.role.rawValue.capitalized): \(entry.content)\n"
            }
            enrichedPrompt += "\n"
        }
        
        enrichedPrompt += "User: \(input)"
        
        let metadata: [String: Any] = [
            "timestamp": Date(),
            "contextParameterCount": contextParameters.filter { $0.isActive }.count,
            "historyCount": relevantHistory.count,
            "temperature": temperature,
            "maxTokens": maxTokens
        ]
        
        let activeFilters = contextParameters
            .filter { $0.isActive && $0.type == .responseStyle }
            .map { param in
                ContextFilter(
                    name: param.name,
                    filterType: .formatEnforcement,
                    pattern: nil
                )
            }
        
        return EnhancedInput(
            originalInput: input,
            enrichedPrompt: enrichedPrompt,
            contextMetadata: metadata,
            relevantHistory: relevantHistory,
            activeFilters: activeFilters
        )
    }
    
    func applyContextualFilters(_ response: String) -> String {
        var filtered = response
        
        // Apply length control if needed
        if filtered.count > maxTokens * 4 { // Rough character estimate
            let endIndex = filtered.index(filtered.startIndex, offsetBy: maxTokens * 4)
            filtered = String(filtered[..<endIndex]) + "..."
        }
        
        // Clean up for voice output
        filtered = filtered
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "##", with: "")
        
        return filtered
    }
}

/// Conversation memory management
class ConversationMemory {
    private var history: [ConversationEntry] = []
    private let maxHistorySize = 100
    
    func addEntry(_ entry: ConversationEntry) {
        history.append(entry)
        if history.count > maxHistorySize {
            history.removeFirst()
        }
    }
    
    func getRelevantHistory(for input: String, limit: Int) -> [ConversationEntry] {
        // Simple recency-based retrieval for now
        // Could be enhanced with semantic similarity in the future
        return Array(history.suffix(limit))
    }
    
    func clear() {
        history.removeAll()
    }
}
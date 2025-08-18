import Foundation

/// Processes voice commands and extracts intents
class VoiceCommandProcessor {
    private let intentClassifier = IntentClassifier()
    private let entityExtractor = EntityExtractor()
    private let systemController = SystemController.shared
    
    func processCommand(_ text: String) -> VoiceCommand {
        let normalizedText = normalize(text)
        
        // First check if it's a system command
        if let systemCommand = systemController.parseVoiceCommand(text) {
            // Create voice command with system intent
            return VoiceCommand(
                originalText: text,
                normalizedText: normalizedText,
                intent: Intent(type: .systemControl, confidence: 0.9),
                entities: extractSystemEntities(from: systemCommand),
                confidence: 0.9,
                timestamp: Date(),
                systemCommand: systemCommand
            )
        }
        
        // Otherwise process as regular command
        let intent = intentClassifier.classify(normalizedText)
        let entities = entityExtractor.extract(from: normalizedText)
        
        return VoiceCommand(
            originalText: text,
            normalizedText: normalizedText,
            intent: intent,
            entities: entities,
            confidence: calculateConfidence(intent: intent, entities: entities),
            timestamp: Date(),
            systemCommand: nil
        )
    }
    
    private func extractSystemEntities(from command: SystemCommand) -> [Entity] {
        var entities: [Entity] = []
        
        // Add category entity
        entities.append(Entity(
            type: .systemCategory,
            value: "\(command.category)",
            confidence: 1.0
        ))
        
        // Add action entity
        entities.append(Entity(
            type: .systemAction,
            value: "\(command.action)",
            confidence: 1.0
        ))
        
        // Add target entity
        if !command.target.isEmpty {
            entities.append(Entity(
                type: .systemTarget,
                value: command.target,
                confidence: 0.9
            ))
        }
        
        return entities
    }
    
    private func normalize(_ text: String) -> String {
        return text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    private func calculateConfidence(intent: Intent, entities: [Entity]) -> Double {
        var confidence = intent.confidence
        
        // Adjust confidence based on entity extraction
        if !entities.isEmpty {
            let entityConfidence = entities.map { $0.confidence }.reduce(0, +) / Double(entities.count)
            confidence = (confidence + entityConfidence) / 2
        }
        
        return min(1.0, max(0.0, confidence))
    }
}

/// Intent classifier for voice commands
class IntentClassifier {
    private let intents: [IntentPattern] = [
        // AI Interaction
        IntentPattern(type: .askQuestion, patterns: [
            "what", "how", "why", "when", "where", "who", "tell me", "explain"
        ]),
        IntentPattern(type: .generateContent, patterns: [
            "create", "generate", "write", "compose", "draft", "make"
        ]),
        IntentPattern(type: .analyze, patterns: [
            "analyze", "review", "check", "evaluate", "assess", "examine"
        ]),
        
        // System Control
        IntentPattern(type: .changeProvider, patterns: [
            "switch to", "change to", "use", "select provider"
        ]),
        IntentPattern(type: .adjustSettings, patterns: [
            "settings", "configure", "adjust", "change settings", "preferences"
        ]),
        IntentPattern(type: .systemCommand, patterns: [
            "stop", "pause", "resume", "cancel", "clear", "reset"
        ]),
        
        // Context Management
        IntentPattern(type: .saveContext, patterns: [
            "save", "remember", "store", "keep"
        ]),
        IntentPattern(type: .loadContext, patterns: [
            "load", "restore", "recall", "retrieve"
        ]),
        IntentPattern(type: .clearContext, patterns: [
            "clear history", "forget", "reset context"
        ])
    ]
    
    func classify(_ text: String) -> Intent {
        var bestMatch: (type: IntentType, score: Double) = (.unknown, 0.0)
        
        for pattern in intents {
            let score = calculateScore(text: text, pattern: pattern)
            if score > bestMatch.score {
                bestMatch = (pattern.type, score)
            }
        }
        
        return Intent(
            type: bestMatch.score > 0.3 ? bestMatch.type : .unknown,
            confidence: bestMatch.score
        )
    }
    
    private func calculateScore(text: String, pattern: IntentPattern) -> Double {
        let words = text.split(separator: " ").map { String($0) }
        var matchCount = 0
        
        for word in words {
            if pattern.patterns.contains(where: { word.contains($0) }) {
                matchCount += 1
            }
        }
        
        return Double(matchCount) / Double(max(1, pattern.patterns.count))
    }
}

/// Entity extractor for voice commands
class EntityExtractor {
    func extract(from text: String) -> [Entity] {
        var entities: [Entity] = []
        
        // Extract AI provider mentions
        if let provider = extractProvider(from: text) {
            entities.append(Entity(
                type: .provider,
                value: provider,
                confidence: 0.9
            ))
        }
        
        // Extract numbers
        let numbers = extractNumbers(from: text)
        for number in numbers {
            entities.append(Entity(
                type: .number,
                value: number,
                confidence: 0.95
            ))
        }
        
        // Extract settings
        if let setting = extractSetting(from: text) {
            entities.append(Entity(
                type: .setting,
                value: setting,
                confidence: 0.85
            ))
        }
        
        return entities
    }
    
    private func extractProvider(from text: String) -> String? {
        let providers = ["openai", "gemini", "local", "gpt", "claude", "llama"]
        
        for provider in providers {
            if text.contains(provider) {
                return provider
            }
        }
        
        return nil
    }
    
    private func extractNumbers(from text: String) -> [String] {
        let pattern = #"\d+(\.\d+)?"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        
        return matches.compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
    
    private func extractSetting(from text: String) -> String? {
        let settings = ["temperature", "tokens", "context", "voice", "speed", "volume"]
        
        for setting in settings {
            if text.contains(setting) {
                return setting
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Types

struct VoiceCommand {
    let originalText: String
    let normalizedText: String
    let intent: Intent
    let entities: [Entity]
    let confidence: Double
    let timestamp: Date
    var systemCommand: SystemCommand?
}

struct Intent {
    let type: IntentType
    let confidence: Double
}

enum IntentType: String {
    case askQuestion = "ask_question"
    case generateContent = "generate_content"
    case analyze = "analyze"
    case changeProvider = "change_provider"
    case adjustSettings = "adjust_settings"
    case systemCommand = "system_command"
    case systemControl = "system_control"
    case saveContext = "save_context"
    case loadContext = "load_context"
    case clearContext = "clear_context"
    case unknown = "unknown"
}

struct Entity {
    let type: EntityType
    let value: String
    let confidence: Double
}

enum EntityType: String {
    case provider = "provider"
    case number = "number"
    case setting = "setting"
    case text = "text"
    case systemCategory = "system_category"
    case systemAction = "system_action"
    case systemTarget = "system_target"
}

struct IntentPattern {
    let type: IntentType
    let patterns: [String]
}
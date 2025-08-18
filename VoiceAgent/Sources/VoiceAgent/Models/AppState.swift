import Foundation
import Combine

/// Main application state management
@MainActor
class AppState: ObservableObject {
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var currentTranscription = ""
    @Published var conversationHistory: [ConversationEntry] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var activeProvider: AIProvider = .openai
    @Published var errorMessage: String?
    @Published var isMinimized = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Auto-clear error messages after 5 seconds
        $errorMessage
            .compactMap { $0 }
            .delay(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.errorMessage = nil
            }
            .store(in: &cancellables)
    }
    
    func addConversationEntry(_ entry: ConversationEntry) {
        conversationHistory.append(entry)
        // Keep only last 100 entries for memory efficiency
        if conversationHistory.count > 100 {
            conversationHistory.removeFirst()
        }
    }
    
    func clearHistory() {
        conversationHistory.removeAll()
    }
}

struct ConversationEntry: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let role: Role
    let content: String
    let provider: AIProvider?
    
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
}

enum ConnectionStatus {
    case connected
    case connecting
    case disconnected
    case error(String)
    
    var description: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var color: String {
        switch self {
        case .connected:
            return "green"
        case .connecting:
            return "yellow"
        case .disconnected, .error:
            return "red"
        }
    }
}

enum AIProvider: String, CaseIterable, Codable {
    case openai = "OpenAI"
    case gemini = "Gemini"
    case local = "Local Model"
    
    var icon: String {
        switch self {
        case .openai:
            return "brain"
        case .gemini:
            return "sparkles"
        case .local:
            return "desktopcomputer"
        }
    }
}
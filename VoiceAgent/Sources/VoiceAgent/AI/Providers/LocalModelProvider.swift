import Foundation
import Alamofire
import SwiftyJSON

/// Local Model Provider for Ollama, llama.cpp, or other local model servers
class LocalModelProvider: AIProviderProtocol {
    var type: AIProvider { .local }
    
    private var settings: ProviderSettings?
    private var session: Session
    
    var isConfigured: Bool {
        settings?.endpoint != nil
    }
    
    init() {
        // Configure session with custom timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300
        
        self.session = Session(configuration: configuration)
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        // Load from UserDefaults
        let endpoint = UserDefaults.standard.string(forKey: "local_model_endpoint") ?? "http://localhost:11434"
        let model = UserDefaults.standard.string(forKey: "local_model_name") ?? "llama2"
        
        settings = ProviderSettings(
            endpoint: endpoint,
            model: model,
            maxTokens: 2048,
            temperature: 0.7
        )
    }
    
    func configure(with settings: ProviderSettings) throws {
        guard let endpoint = settings.endpoint, !endpoint.isEmpty else {
            throw AIError.providerNotConfigured
        }
        
        self.settings = settings
        
        // Save to UserDefaults
        UserDefaults.standard.set(endpoint, forKey: "local_model_endpoint")
        UserDefaults.standard.set(settings.model ?? "llama2", forKey: "local_model_name")
    }
    
    func validateConfiguration() -> Bool {
        guard let endpoint = settings?.endpoint else { return false }
        
        // Test connection to local model server
        let semaphore = DispatchSemaphore(value: 0)
        var isValid = false
        
        session.request("\(endpoint)/api/tags")
            .validate()
            .response { response in
                isValid = response.error == nil
                semaphore.signal()
            }
        
        _ = semaphore.wait(timeout: .now() + 5)
        return isValid
    }
    
    func generateResponse(_ input: EnhancedInput) async throws -> String {
        guard let endpoint = settings?.endpoint else {
            throw AIError.providerNotConfigured
        }
        
        let model = settings?.model ?? "llama2"
        
        // Build request body for Ollama API format
        let requestBody: [String: Any] = [
            "model": model,
            "prompt": buildPrompt(from: input),
            "stream": false,
            "options": [
                "temperature": settings?.temperature ?? input.contextMetadata["temperature"] as? Double ?? 0.7,
                "num_predict": settings?.maxTokens ?? input.contextMetadata["maxTokens"] as? Int ?? 2048
            ]
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(endpoint)/api/generate",
                method: .post,
                parameters: requestBody,
                encoding: JSONEncoding.default
            )
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        if let responseText = json["response"].string {
                            continuation.resume(returning: responseText)
                        } else {
                            continuation.resume(throwing: AIError.invalidResponse)
                        }
                    } catch {
                        continuation.resume(throwing: AIError.invalidResponse)
                    }
                    
                case .failure(let error):
                    if error.isSessionTaskError {
                        continuation.resume(throwing: AIError.networkError("Connection to local model failed. Ensure the model server is running."))
                    } else {
                        continuation.resume(throwing: AIError.networkError(error.localizedDescription))
                    }
                }
            }
        }
    }
    
    private func buildPrompt(from input: EnhancedInput) -> String {
        var prompt = ""
        
        // Add system context
        if !input.enrichedPrompt.isEmpty {
            prompt += "System: \(input.enrichedPrompt)\n\n"
        }
        
        // Add conversation history
        for entry in input.relevantHistory {
            let role = entry.role == .user ? "User" : "Assistant"
            prompt += "\(role): \(entry.content)\n"
        }
        
        // Add current input
        prompt += "User: \(input.originalInput)\nAssistant:"
        
        return prompt
    }
    
    // Alternative method for llama.cpp server format
    func generateResponseLlamaCpp(_ input: EnhancedInput) async throws -> String {
        guard let endpoint = settings?.endpoint else {
            throw AIError.providerNotConfigured
        }
        
        let requestBody: [String: Any] = [
            "prompt": buildPrompt(from: input),
            "n_predict": settings?.maxTokens ?? 2048,
            "temperature": settings?.temperature ?? 0.7,
            "stop": ["User:", "\n\n"],
            "stream": false
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(endpoint)/completion",
                method: .post,
                parameters: requestBody,
                encoding: JSONEncoding.default
            )
            .validate()
            .responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        let json = try JSON(data: data)
                        if let content = json["content"].string {
                            continuation.resume(returning: content)
                        } else {
                            continuation.resume(throwing: AIError.invalidResponse)
                        }
                    } catch {
                        continuation.resume(throwing: AIError.invalidResponse)
                    }
                    
                case .failure(let error):
                    continuation.resume(throwing: AIError.networkError(error.localizedDescription))
                }
            }
        }
    }
}

// MARK: - Local Model Discovery
extension LocalModelProvider {
    /// Discover available models on the local server
    func discoverModels() async throws -> [String] {
        guard let endpoint = settings?.endpoint else {
            throw AIError.providerNotConfigured
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request("\(endpoint)/api/tags")
                .validate()
                .responseData { response in
                    switch response.result {
                    case .success(let data):
                        do {
                            let json = try JSON(data: data)
                            let models = json["models"].arrayValue.compactMap { $0["name"].string }
                            continuation.resume(returning: models)
                        } catch {
                            continuation.resume(returning: [])
                        }
                        
                    case .failure(let error):
                        continuation.resume(throwing: AIError.networkError(error.localizedDescription))
                    }
                }
        }
    }
    
    /// Pull a model from Ollama library
    func pullModel(_ modelName: String) async throws {
        guard let endpoint = settings?.endpoint else {
            throw AIError.providerNotConfigured
        }
        
        let requestBody: [String: Any] = [
            "name": modelName,
            "stream": false
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                "\(endpoint)/api/pull",
                method: .post,
                parameters: requestBody,
                encoding: JSONEncoding.default
            )
            .validate()
            .response { response in
                if let error = response.error {
                    continuation.resume(throwing: AIError.networkError(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
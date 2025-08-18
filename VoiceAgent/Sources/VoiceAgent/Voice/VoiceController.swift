import Foundation
import Speech
import AVFoundation
import Combine

/// Main voice controller for real-time speech recognition and synthesis
@MainActor
class VoiceController: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var audioLevel: Float = 0.0
    @Published var isSpeaking = false
    @Published var recognitionStatus: RecognitionStatus = .ready
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private var audioLevelTimer: Timer?
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.0
    private var lastSpeechTime = Date()
    
    private let commandProcessor = VoiceCommandProcessor()
    private var cancellables = Set<AnyCancellable>()
    
    enum RecognitionStatus {
        case ready
        case listening
        case processing
        case error(String)
        
        var description: String {
            switch self {
            case .ready:
                return "Ready"
            case .listening:
                return "Listening..."
            case .processing:
                return "Processing..."
            case .error(let message):
                return "Error: \(message)"
            }
        }
    }
    
    override init() {
        super.init()
        setupSpeechRecognizer()
        speechSynthesizer.delegate = self
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
        
        requestSpeechAuthorization()
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.recognitionStatus = .ready
                case .denied:
                    self?.recognitionStatus = .error("Speech recognition access denied")
                case .restricted:
                    self?.recognitionStatus = .error("Speech recognition restricted")
                case .notDetermined:
                    self?.recognitionStatus = .error("Speech recognition not determined")
                @unknown default:
                    self?.recognitionStatus = .error("Unknown authorization status")
                }
            }
        }
    }
    
    func startListening() {
        guard !isListening else { return }
        
        do {
            try startRecognition()
            isListening = true
            recognitionStatus = .listening
            startAudioLevelMonitoring()
            startSilenceDetection()
        } catch {
            recognitionStatus = .error(error.localizedDescription)
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        isListening = false
        recognitionStatus = .ready
        
        stopAudioLevelMonitoring()
        stopSilenceDetection()
    }
    
    private func startRecognition() throws {
        // Cancel any ongoing recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.recognitionRequestFailed
        }
        
        // Configure recognition request
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        recognitionRequest.taskHint = .dictation
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.lastSpeechTime = Date()
                    
                    if result.isFinal {
                        self.processTranscription(result.bestTranscription.formattedString)
                    }
                }
                
                if let error = error {
                    self.recognitionStatus = .error(error.localizedDescription)
                    self.stopListening()
                }
            }
        }
        
        // Configure audio format and install tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level for visualization
            self?.calculateAudioLevel(from: buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))
        
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        
        DispatchQueue.main.async {
            self.audioLevel = max(0, min(1, (avgPower + 50) / 50))
        }
    }
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Audio level is updated in calculateAudioLevel
            // This timer ensures UI updates
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
    
    private func startSilenceDetection() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let timeSinceLastSpeech = Date().timeIntervalSince(self.lastSpeechTime)
            
            if timeSinceLastSpeech > self.silenceThreshold && !self.transcribedText.isEmpty {
                self.processTranscription(self.transcribedText)
                self.transcribedText = ""
                self.lastSpeechTime = Date()
            }
        }
    }
    
    private func stopSilenceDetection() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    private func processTranscription(_ text: String) {
        recognitionStatus = .processing
        
        // Process voice command
        let command = commandProcessor.processCommand(text)
        
        // Notify observers
        NotificationCenter.default.post(
            name: .voiceCommandReceived,
            object: nil,
            userInfo: ["command": command, "text": text]
        )
    }
    
    func speak(_ text: String, voice: VoiceType = .default) {
        guard !isSpeaking else { return }
        
        isSpeaking = true
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = voice.rate
        utterance.pitchMultiplier = voice.pitch
        utterance.volume = voice.volume
        
        if let voiceIdentifier = voice.identifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
}

// MARK: - Speech Recognizer Delegate
extension VoiceController: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recognitionStatus = .ready
        } else {
            recognitionStatus = .error("Speech recognition not available")
        }
    }
}

// MARK: - Speech Synthesizer Delegate
extension VoiceController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }
}

// MARK: - Supporting Types
enum VoiceError: LocalizedError {
    case recognitionRequestFailed
    case audioEngineError
    case microphoneAccessDenied
    
    var errorDescription: String? {
        switch self {
        case .recognitionRequestFailed:
            return "Failed to create recognition request"
        case .audioEngineError:
            return "Audio engine error"
        case .microphoneAccessDenied:
            return "Microphone access denied"
        }
    }
}

struct VoiceType {
    let identifier: String?
    let rate: Float
    let pitch: Float
    let volume: Float
    
    static let `default` = VoiceType(
        identifier: nil,
        rate: 0.5,
        pitch: 1.0,
        volume: 0.9
    )
    
    static let fast = VoiceType(
        identifier: nil,
        rate: 0.6,
        pitch: 1.1,
        volume: 0.9
    )
    
    static let slow = VoiceType(
        identifier: nil,
        rate: 0.4,
        pitch: 0.9,
        volume: 0.9
    )
}

// MARK: - Notification Names
extension Notification.Name {
    static let voiceCommandReceived = Notification.Name("voiceCommandReceived")
    static let voiceResponseReady = Notification.Name("voiceResponseReady")
}
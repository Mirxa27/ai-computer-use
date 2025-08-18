import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

/// Main system controller for complete computer control via voice commands
@MainActor
class SystemController: ObservableObject {
    static let shared = SystemController()
    
    private let applicationController = ApplicationController()
    private let fileSystemController = FileSystemController()
    private let windowManager = WindowManager()
    private let inputSimulator = InputSimulator()
    private let systemSettings = SystemSettingsController()
    private let accessibilityBridge = AccessibilityBridge()
    private let automationExecutor = AutomationExecutor()
    
    @Published var isExecutingCommand = false
    @Published var lastCommandResult: CommandResult?
    @Published var requiresPermission: SystemPermission?
    
    init() {
        checkPermissions()
    }
    
    /// Execute a system control command
    func executeCommand(_ command: SystemCommand) async throws -> CommandResult {
        isExecutingCommand = true
        defer { isExecutingCommand = false }
        
        // Check permissions
        guard await checkPermissionFor(command) else {
            throw SystemControlError.permissionDenied(command.requiredPermission)
        }
        
        let result: CommandResult
        
        switch command.category {
        case .application:
            result = try await applicationController.execute(command)
            
        case .fileSystem:
            result = try await fileSystemController.execute(command)
            
        case .window:
            result = try await windowManager.execute(command)
            
        case .input:
            result = try await inputSimulator.execute(command)
            
        case .system:
            result = try await systemSettings.execute(command)
            
        case .accessibility:
            result = try await accessibilityBridge.execute(command)
            
        case .automation:
            result = try await automationExecutor.execute(command)
            
        case .navigation:
            result = try await executeNavigation(command)
            
        case .media:
            result = try await executeMediaControl(command)
            
        case .display:
            result = try await executeDisplayControl(command)
        }
        
        lastCommandResult = result
        
        // Log command execution
        logCommand(command, result: result)
        
        return result
    }
    
    /// Parse voice input into system command
    func parseVoiceCommand(_ input: String) -> SystemCommand? {
        let normalizedInput = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Application commands
        if normalizedInput.contains("open") || normalizedInput.contains("launch") {
            return parseApplicationCommand(normalizedInput, action: .open)
        }
        
        if normalizedInput.contains("close") || normalizedInput.contains("quit") {
            return parseApplicationCommand(normalizedInput, action: .close)
        }
        
        if normalizedInput.contains("switch to") || normalizedInput.contains("focus") {
            return parseApplicationCommand(normalizedInput, action: .switchTo)
        }
        
        // File system commands
        if normalizedInput.contains("create") && normalizedInput.contains("folder") {
            return parseFileSystemCommand(normalizedInput, action: .createFolder)
        }
        
        if normalizedInput.contains("delete") || normalizedInput.contains("remove") {
            return parseFileSystemCommand(normalizedInput, action: .delete)
        }
        
        if normalizedInput.contains("move") || normalizedInput.contains("rename") {
            return parseFileSystemCommand(normalizedInput, action: .move)
        }
        
        // Window commands
        if normalizedInput.contains("minimize") {
            return SystemCommand(category: .window, action: .minimize, target: "current")
        }
        
        if normalizedInput.contains("maximize") || normalizedInput.contains("full screen") {
            return SystemCommand(category: .window, action: .maximize, target: "current")
        }
        
        if normalizedInput.contains("arrange windows") {
            return SystemCommand(category: .window, action: .arrange, target: "all")
        }
        
        // System commands
        if normalizedInput.contains("sleep") || normalizedInput.contains("lock") {
            return SystemCommand(category: .system, action: .sleep, target: "system")
        }
        
        if normalizedInput.contains("restart") || normalizedInput.contains("reboot") {
            return SystemCommand(category: .system, action: .restart, target: "system")
        }
        
        if normalizedInput.contains("shutdown") {
            return SystemCommand(category: .system, action: .shutdown, target: "system")
        }
        
        // Navigation commands
        if normalizedInput.contains("scroll") {
            return parseScrollCommand(normalizedInput)
        }
        
        if normalizedInput.contains("click") || normalizedInput.contains("tap") {
            return parseClickCommand(normalizedInput)
        }
        
        if normalizedInput.contains("type") || normalizedInput.contains("write") {
            return parseTypeCommand(normalizedInput)
        }
        
        // Media commands
        if normalizedInput.contains("play") || normalizedInput.contains("pause") {
            return SystemCommand(category: .media, action: .playPause, target: "system")
        }
        
        if normalizedInput.contains("volume") {
            return parseVolumeCommand(normalizedInput)
        }
        
        if normalizedInput.contains("brightness") {
            return parseBrightnessCommand(normalizedInput)
        }
        
        // Screenshot/recording
        if normalizedInput.contains("screenshot") || normalizedInput.contains("capture") {
            return SystemCommand(category: .display, action: .screenshot, target: "screen")
        }
        
        if normalizedInput.contains("record") {
            return SystemCommand(category: .display, action: .startRecording, target: "screen")
        }
        
        return nil
    }
    
    // MARK: - Command Parsing Helpers
    
    private func parseApplicationCommand(_ input: String, action: CommandAction) -> SystemCommand {
        var target = ""
        
        // Common applications
        let apps = [
            "safari", "chrome", "firefox",
            "mail", "messages", "facetime",
            "calendar", "notes", "reminders",
            "music", "spotify", "tv",
            "finder", "terminal", "xcode",
            "slack", "discord", "teams",
            "photoshop", "illustrator", "figma",
            "word", "excel", "powerpoint",
            "preview", "pages", "numbers", "keynote"
        ]
        
        for app in apps {
            if input.contains(app) {
                target = app
                break
            }
        }
        
        if target.isEmpty {
            // Try to extract app name after keywords
            if let range = input.range(of: "open ") ?? input.range(of: "launch ") {
                target = String(input[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return SystemCommand(
            category: .application,
            action: action,
            target: target,
            parameters: ["appName": target]
        )
    }
    
    private func parseFileSystemCommand(_ input: String, action: CommandAction) -> SystemCommand {
        var target = ""
        var parameters: [String: Any] = [:]
        
        // Extract path or filename
        if input.contains("desktop") {
            target = "~/Desktop"
        } else if input.contains("documents") {
            target = "~/Documents"
        } else if input.contains("downloads") {
            target = "~/Downloads"
        }
        
        // Extract folder/file name
        if action == .createFolder {
            if let range = input.range(of: "folder named ") ?? input.range(of: "folder called ") {
                let name = String(input[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                parameters["name"] = name
            }
        }
        
        return SystemCommand(
            category: .fileSystem,
            action: action,
            target: target,
            parameters: parameters
        )
    }
    
    private func parseScrollCommand(_ input: String) -> SystemCommand {
        var direction = "down"
        var amount = 3
        
        if input.contains("up") {
            direction = "up"
        } else if input.contains("left") {
            direction = "left"
        } else if input.contains("right") {
            direction = "right"
        }
        
        // Extract amount
        if let match = input.range(of: #"\d+"#, options: .regularExpression) {
            if let value = Int(input[match]) {
                amount = value
            }
        }
        
        return SystemCommand(
            category: .navigation,
            action: .scroll,
            target: "current",
            parameters: ["direction": direction, "amount": amount]
        )
    }
    
    private func parseClickCommand(_ input: String) -> SystemCommand {
        var clickType = "left"
        
        if input.contains("right") {
            clickType = "right"
        } else if input.contains("double") {
            clickType = "double"
        }
        
        return SystemCommand(
            category: .input,
            action: .click,
            target: "mouse",
            parameters: ["type": clickType]
        )
    }
    
    private func parseTypeCommand(_ input: String) -> SystemCommand {
        var text = ""
        
        if let range = input.range(of: "type ") ?? input.range(of: "write ") {
            text = String(input[range.upperBound...])
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "\"", with: "")
        }
        
        return SystemCommand(
            category: .input,
            action: .type,
            target: "keyboard",
            parameters: ["text": text]
        )
    }
    
    private func parseVolumeCommand(_ input: String) -> SystemCommand {
        var action: CommandAction = .setVolume
        var level = 50
        
        if input.contains("mute") {
            action = .mute
        } else if input.contains("unmute") {
            action = .unmute
        } else if input.contains("up") || input.contains("increase") {
            action = .increaseVolume
        } else if input.contains("down") || input.contains("decrease") {
            action = .decreaseVolume
        }
        
        // Extract level
        if let match = input.range(of: #"\d+"#, options: .regularExpression) {
            if let value = Int(input[match]) {
                level = min(100, max(0, value))
            }
        }
        
        return SystemCommand(
            category: .media,
            action: action,
            target: "audio",
            parameters: ["level": level]
        )
    }
    
    private func parseBrightnessCommand(_ input: String) -> SystemCommand {
        var level = 50
        
        if let match = input.range(of: #"\d+"#, options: .regularExpression) {
            if let value = Int(input[match]) {
                level = min(100, max(0, value))
            }
        }
        
        return SystemCommand(
            category: .display,
            action: .setBrightness,
            target: "display",
            parameters: ["level": level]
        )
    }
    
    // MARK: - Navigation Commands
    
    private func executeNavigation(_ command: SystemCommand) async throws -> CommandResult {
        switch command.action {
        case .scroll:
            let direction = command.parameters["direction"] as? String ?? "down"
            let amount = command.parameters["amount"] as? Int ?? 3
            
            try await inputSimulator.scroll(direction: direction, amount: amount)
            return CommandResult(success: true, message: "Scrolled \(direction) by \(amount)")
            
        case .goBack:
            try await inputSimulator.pressKey(.leftArrow, modifiers: [.command])
            return CommandResult(success: true, message: "Navigated back")
            
        case .goForward:
            try await inputSimulator.pressKey(.rightArrow, modifiers: [.command])
            return CommandResult(success: true, message: "Navigated forward")
            
        case .refresh:
            try await inputSimulator.pressKey(.r, modifiers: [.command])
            return CommandResult(success: true, message: "Refreshed page")
            
        case .newTab:
            try await inputSimulator.pressKey(.t, modifiers: [.command])
            return CommandResult(success: true, message: "Opened new tab")
            
        case .closeTab:
            try await inputSimulator.pressKey(.w, modifiers: [.command])
            return CommandResult(success: true, message: "Closed tab")
            
        case .switchTab:
            let tabIndex = command.parameters["index"] as? Int ?? 1
            try await inputSimulator.pressKey(.init(rawValue: 18 + tabIndex)!, modifiers: [.command])
            return CommandResult(success: true, message: "Switched to tab \(tabIndex)")
            
        default:
            throw SystemControlError.unsupportedAction(command.action)
        }
    }
    
    // MARK: - Media Control
    
    private func executeMediaControl(_ command: SystemCommand) async throws -> CommandResult {
        switch command.action {
        case .playPause:
            try await mediaControl(.playPause)
            return CommandResult(success: true, message: "Toggled play/pause")
            
        case .next:
            try await mediaControl(.next)
            return CommandResult(success: true, message: "Skipped to next")
            
        case .previous:
            try await mediaControl(.previous)
            return CommandResult(success: true, message: "Skipped to previous")
            
        case .setVolume, .increaseVolume, .decreaseVolume, .mute, .unmute:
            return try await systemSettings.adjustVolume(command)
            
        default:
            throw SystemControlError.unsupportedAction(command.action)
        }
    }
    
    private func mediaControl(_ action: MediaAction) async throws {
        let script: String
        
        switch action {
        case .playPause:
            script = "tell application \"System Events\" to key code 49"
        case .next:
            script = "tell application \"System Events\" to key code 124 using {command down}"
        case .previous:
            script = "tell application \"System Events\" to key code 123 using {command down}"
        }
        
        try await automationExecutor.runAppleScript(script)
    }
    
    // MARK: - Display Control
    
    private func executeDisplayControl(_ command: SystemCommand) async throws -> CommandResult {
        switch command.action {
        case .screenshot:
            try await inputSimulator.pressKey(.three, modifiers: [.command, .shift])
            return CommandResult(success: true, message: "Screenshot captured")
            
        case .startRecording:
            try await inputSimulator.pressKey(.five, modifiers: [.command, .shift])
            return CommandResult(success: true, message: "Screen recording started")
            
        case .setBrightness:
            let level = command.parameters["level"] as? Int ?? 50
            return try await systemSettings.setBrightness(level)
            
        default:
            throw SystemControlError.unsupportedAction(command.action)
        }
    }
    
    // MARK: - Permission Management
    
    private func checkPermissions() {
        Task {
            let permissions: [SystemPermission] = [
                .accessibility,
                .screenRecording,
                .automation,
                .fullDiskAccess
            ]
            
            for permission in permissions {
                let granted = await checkPermission(permission)
                if !granted {
                    requiresPermission = permission
                    break
                }
            }
        }
    }
    
    private func checkPermissionFor(_ command: SystemCommand) async -> Bool {
        return await checkPermission(command.requiredPermission)
    }
    
    private func checkPermission(_ permission: SystemPermission) async -> Bool {
        switch permission {
        case .accessibility:
            return AXIsProcessTrusted()
            
        case .screenRecording:
            return CGPreflightScreenCaptureAccess()
            
        case .automation:
            // Check AppleEvents permission
            return true // Simplified - actual implementation would check specific permission
            
        case .fullDiskAccess:
            // Check if we can access protected directories
            return FileManager.default.isReadableFile(atPath: "/Library/Application Support/com.apple.TCC/TCC.db")
            
        case .none:
            return true
        }
    }
    
    func requestPermission(_ permission: SystemPermission) {
        switch permission {
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            
        case .screenRecording:
            CGRequestScreenCaptureAccess()
            
        case .automation:
            // Request automation permission
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
            
        case .fullDiskAccess:
            // Open Full Disk Access settings
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            
        case .none:
            break
        }
    }
    
    // MARK: - Logging
    
    private func logCommand(_ command: SystemCommand, result: CommandResult) {
        let logEntry = CommandLog(
            timestamp: Date(),
            command: command,
            result: result,
            executionTime: result.executionTime ?? 0
        )
        
        // Store in history
        CommandHistory.shared.add(logEntry)
        
        // Post notification
        NotificationCenter.default.post(
            name: .systemCommandExecuted,
            object: nil,
            userInfo: ["log": logEntry]
        )
    }
}

// MARK: - Supporting Types

struct SystemCommand {
    let category: CommandCategory
    let action: CommandAction
    let target: String
    var parameters: [String: Any] = [:]
    
    var requiredPermission: SystemPermission {
        switch category {
        case .application, .window, .navigation, .input:
            return .accessibility
        case .display:
            return .screenRecording
        case .automation:
            return .automation
        case .fileSystem:
            return .fullDiskAccess
        case .system, .media:
            return .none
        case .accessibility:
            return .accessibility
        }
    }
}

enum CommandCategory {
    case application
    case fileSystem
    case window
    case input
    case system
    case accessibility
    case automation
    case navigation
    case media
    case display
}

enum CommandAction {
    // Application
    case open, close, switchTo, hide, show
    
    // File System
    case createFolder, createFile, delete, move, copy, rename
    
    // Window
    case minimize, maximize, restore, arrange, resize, position
    
    // Input
    case click, rightClick, doubleClick, drag, type, pressKey
    
    // System
    case sleep, wake, restart, shutdown, logout, lock
    
    // Navigation
    case scroll, goBack, goForward, refresh, newTab, closeTab, switchTab
    
    // Media
    case playPause, next, previous, setVolume, increaseVolume, decreaseVolume, mute, unmute
    
    // Display
    case screenshot, startRecording, stopRecording, setBrightness
    
    // Custom
    case custom(String)
}

struct CommandResult {
    let success: Bool
    let message: String
    var output: Any?
    var error: Error?
    var executionTime: TimeInterval?
}

enum SystemPermission {
    case accessibility
    case screenRecording
    case automation
    case fullDiskAccess
    case none
}

enum SystemControlError: LocalizedError {
    case permissionDenied(SystemPermission)
    case applicationNotFound(String)
    case fileNotFound(String)
    case unsupportedAction(CommandAction)
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .applicationNotFound(let app):
            return "Application not found: \(app)"
        case .fileNotFound(let file):
            return "File not found: \(file)"
        case .unsupportedAction(let action):
            return "Unsupported action: \(action)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        }
    }
}

enum MediaAction {
    case playPause, next, previous
}

// MARK: - Command History

class CommandHistory {
    static let shared = CommandHistory()
    private var history: [CommandLog] = []
    private let maxHistorySize = 100
    
    func add(_ log: CommandLog) {
        history.append(log)
        if history.count > maxHistorySize {
            history.removeFirst()
        }
    }
    
    func getRecent(_ count: Int) -> [CommandLog] {
        Array(history.suffix(count))
    }
}

struct CommandLog {
    let timestamp: Date
    let command: SystemCommand
    let result: CommandResult
    let executionTime: TimeInterval
}

// MARK: - Notification Names
extension Notification.Name {
    static let systemCommandExecuted = Notification.Name("systemCommandExecuted")
    static let permissionRequired = Notification.Name("permissionRequired")
}
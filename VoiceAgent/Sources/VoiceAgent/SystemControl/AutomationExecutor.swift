import Foundation
import AppKit

/// Executes automation scripts and workflows
class AutomationExecutor {
    private let scriptCache = NSCache<NSString, AutomationScript>()
    
    /// Execute automation command
    func execute(_ command: SystemCommand) async throws -> CommandResult {
        let scriptName = command.parameters["script"] as? String ?? ""
        let scriptContent = command.parameters["content"] as? String ?? ""
        let scriptType = command.parameters["type"] as? ScriptType ?? .appleScript
        
        switch scriptType {
        case .appleScript:
            return try await runAppleScript(scriptContent)
            
        case .shellScript:
            return try await runShellScript(scriptContent)
            
        case .workflow:
            return try await runWorkflow(scriptName)
            
        case .shortcut:
            return try await runShortcut(scriptName)
        }
    }
    
    /// Run AppleScript
    func runAppleScript(_ script: String) async throws -> CommandResult {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    let result = scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        continuation.resume(throwing: SystemControlError.executionFailed(
                            error["NSAppleScriptErrorMessage"] as? String ?? "AppleScript error"
                        ))
                    } else {
                        let output = result.stringValue ?? ""
                        continuation.resume(returning: CommandResult(
                            success: true,
                            message: "Script executed",
                            output: output
                        ))
                    }
                } else {
                    continuation.resume(throwing: SystemControlError.executionFailed("Invalid AppleScript"))
                }
            }
        }
    }
    
    /// Run shell script
    private func runShellScript(_ script: String) async throws -> CommandResult {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        return try await withCheckedThrowingContinuation { continuation in
            task.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if process.terminationStatus == 0 {
                    continuation.resume(returning: CommandResult(
                        success: true,
                        message: "Shell script executed",
                        output: output
                    ))
                } else {
                    continuation.resume(throwing: SystemControlError.executionFailed(
                        "Shell script failed with status \(process.terminationStatus): \(output)"
                    ))
                }
            }
            
            do {
                try task.run()
            } catch {
                continuation.resume(throwing: SystemControlError.executionFailed(
                    "Failed to run shell script: \(error.localizedDescription)"
                ))
            }
        }
    }
    
    /// Run Automator workflow
    private func runWorkflow(_ name: String) async throws -> CommandResult {
        let workflowPaths = [
            "~/Library/Services/\(name).workflow",
            "~/Library/Workflows/Applications/\(name).workflow",
            "/Library/Automator/\(name).workflow"
        ].map { NSString(string: $0).expandingTildeInPath }
        
        var workflowPath: String?
        for path in workflowPaths {
            if FileManager.default.fileExists(atPath: path) {
                workflowPath = path
                break
            }
        }
        
        guard let path = workflowPath else {
            throw SystemControlError.fileNotFound("Workflow '\(name)' not found")
        }
        
        let script = """
            tell application "Automator"
                open "\(path)"
                execute workflow "\(name)"
            end tell
        """
        
        return try await runAppleScript(script)
    }
    
    /// Run Shortcuts app shortcut
    private func runShortcut(_ name: String) async throws -> CommandResult {
        let script = """
            tell application "Shortcuts"
                run shortcut "\(name)"
            end tell
        """
        
        return try await runAppleScript(script)
    }
    
    // MARK: - Predefined Automations
    
    /// Create and cache common automation scripts
    func loadPredefinedAutomations() {
        // Web search automation
        cacheScript(
            name: "web_search",
            content: """
                on run {query}
                    tell application "Safari"
                        activate
                        open location "https://www.google.com/search?q=" & query
                    end tell
                end run
            """,
            type: .appleScript
        )
        
        // Email composition
        cacheScript(
            name: "compose_email",
            content: """
                on run {recipient, subject, body}
                    tell application "Mail"
                        activate
                        set newMessage to make new outgoing message with properties {subject:subject, content:body}
                        tell newMessage
                            make new to recipient at end of to recipients with properties {address:recipient}
                        end tell
                    end tell
                end run
            """,
            type: .appleScript
        )
        
        // Take note
        cacheScript(
            name: "take_note",
            content: """
                on run {noteText}
                    tell application "Notes"
                        activate
                        make new note with properties {body:noteText}
                    end tell
                end run
            """,
            type: .appleScript
        )
        
        // System information
        cacheScript(
            name: "system_info",
            content: "system_profiler SPSoftwareDataType SPHardwareDataType",
            type: .shellScript
        )
        
        // Network diagnostics
        cacheScript(
            name: "network_info",
            content: "ifconfig && networksetup -listallhardwareports",
            type: .shellScript
        )
        
        // Clean desktop
        cacheScript(
            name: "clean_desktop",
            content: """
                tell application "Finder"
                    set desktop_items to items of desktop
                    repeat with item_ref in desktop_items
                        if kind of item_ref is not "Volume" then
                            move item_ref to folder "Desktop Archive" of home
                        end if
                    end repeat
                end tell
            """,
            type: .appleScript
        )
    }
    
    /// Cache automation script
    private func cacheScript(name: String, content: String, type: ScriptType) {
        let script = AutomationScript(name: name, content: content, type: type)
        scriptCache.setObject(script, forKey: name as NSString)
    }
    
    /// Run cached automation
    func runCachedAutomation(_ name: String, parameters: [String] = []) async throws -> CommandResult {
        guard let script = scriptCache.object(forKey: name as NSString) else {
            throw SystemControlError.executionFailed("Automation '\(name)' not found")
        }
        
        var scriptContent = script.content
        
        // Replace parameters in script
        for (index, param) in parameters.enumerated() {
            scriptContent = scriptContent.replacingOccurrences(
                of: "{{\(index)}}",
                with: param
            )
        }
        
        switch script.type {
        case .appleScript:
            return try await runAppleScript(scriptContent)
        case .shellScript:
            return try await runShellScript(scriptContent)
        default:
            throw SystemControlError.unsupportedAction(.custom("Unsupported script type"))
        }
    }
    
    // MARK: - Complex Automations
    
    /// Open multiple URLs in browser
    func openURLs(_ urls: [String]) async throws -> CommandResult {
        let script = """
            tell application "Safari"
                activate
                \(urls.map { "open location \"\($0)\"" }.joined(separator: "\n"))
            end tell
        """
        
        return try await runAppleScript(script)
    }
    
    /// Create calendar event
    func createCalendarEvent(title: String, date: Date, duration: TimeInterval) async throws -> CommandResult {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy HH:mm"
        
        let startDate = formatter.string(from: date)
        let endDate = formatter.string(from: date.addingTimeInterval(duration))
        
        let script = """
            tell application "Calendar"
                activate
                tell calendar "Home"
                    make new event with properties {summary:"\(title)", start date:date "\(startDate)", end date:date "\(endDate)"}
                end tell
            end tell
        """
        
        return try await runAppleScript(script)
    }
    
    /// Send notification
    func sendNotification(title: String, message: String, sound: String? = nil) async throws -> CommandResult {
        let script = """
            display notification "\(message)" with title "\(title)"\(sound != nil ? " sound name \"\(sound!)\"" : "")
        """
        
        return try await runAppleScript(script)
    }
    
    /// Batch file operations
    func batchFileOperation(operation: String, files: [String]) async throws -> CommandResult {
        let script: String
        
        switch operation {
        case "compress":
            script = """
                tell application "Finder"
                    set fileList to {\(files.map { "\"\($0)\"" }.joined(separator: ", "))}
                    set archiveName to "Archive.zip"
                    do shell script "zip -r ~/Desktop/" & archiveName & " " & fileList
                end tell
            """
            
        case "convert_images":
            script = """
                do shell script "for f in \(files.joined(separator: " ")); do sips -s format jpeg $f --out ${f%.*}.jpg; done"
            """
            
        case "rename_batch":
            script = """
                tell application "Finder"
                    set counter to 1
                    repeat with filePath in {\(files.map { "\"\($0)\"" }.joined(separator: ", "))}
                        set name of file filePath to "File_" & counter & ".txt"
                        set counter to counter + 1
                    end repeat
                end tell
            """
            
        default:
            throw SystemControlError.unsupportedAction(.custom(operation))
        }
        
        return try await runAppleScript(script)
    }
}

// MARK: - Supporting Types

enum ScriptType {
    case appleScript
    case shellScript
    case workflow
    case shortcut
}

class AutomationScript: NSObject {
    let name: String
    let content: String
    let type: ScriptType
    let createdAt: Date
    
    init(name: String, content: String, type: ScriptType) {
        self.name = name
        self.content = content
        self.type = type
        self.createdAt = Date()
    }
}
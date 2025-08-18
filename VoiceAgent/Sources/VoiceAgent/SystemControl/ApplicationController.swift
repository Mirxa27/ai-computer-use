import Foundation
import AppKit
import ApplicationServices

/// Controls application launching, switching, and management
class ApplicationController {
    private let workspace = NSWorkspace.shared
    
    /// Execute application-related commands
    func execute(_ command: SystemCommand) async throws -> CommandResult {
        switch command.action {
        case .open:
            return try await openApplication(command.parameters["appName"] as? String ?? command.target)
            
        case .close:
            return try await closeApplication(command.parameters["appName"] as? String ?? command.target)
            
        case .switchTo:
            return try await switchToApplication(command.parameters["appName"] as? String ?? command.target)
            
        case .hide:
            return try await hideApplication(command.parameters["appName"] as? String ?? command.target)
            
        case .show:
            return try await showApplication(command.parameters["appName"] as? String ?? command.target)
            
        default:
            throw SystemControlError.unsupportedAction(command.action)
        }
    }
    
    /// Open an application by name
    private func openApplication(_ appName: String) async throws -> CommandResult {
        let normalizedName = normalizeAppName(appName)
        
        // Try to find the application
        guard let appURL = findApplication(normalizedName) else {
            // Try common variations
            for variation in getAppNameVariations(normalizedName) {
                if let url = findApplication(variation) {
                    return try await launchApp(at: url, name: variation)
                }
            }
            throw SystemControlError.applicationNotFound(appName)
        }
        
        return try await launchApp(at: appURL, name: normalizedName)
    }
    
    private func launchApp(at url: URL, name: String) async throws -> CommandResult {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = true
        
        do {
            let app = try await workspace.openApplication(at: url, configuration: configuration)
            return CommandResult(
                success: true,
                message: "Opened \(name)",
                output: ["pid": app.processIdentifier, "bundleId": app.bundleIdentifier ?? ""]
            )
        } catch {
            throw SystemControlError.executionFailed("Failed to open \(name): \(error.localizedDescription)")
        }
    }
    
    /// Close an application
    private func closeApplication(_ appName: String) async throws -> CommandResult {
        let normalizedName = normalizeAppName(appName)
        
        // Find running application
        guard let app = findRunningApplication(normalizedName) else {
            return CommandResult(success: false, message: "\(appName) is not running")
        }
        
        // Try graceful termination first
        if app.terminate() {
            return CommandResult(success: true, message: "Closed \(appName)")
        }
        
        // Force quit if needed
        if app.forceTerminate() {
            return CommandResult(success: true, message: "Force quit \(appName)")
        }
        
        throw SystemControlError.executionFailed("Failed to close \(appName)")
    }
    
    /// Switch to an application
    private func switchToApplication(_ appName: String) async throws -> CommandResult {
        let normalizedName = normalizeAppName(appName)
        
        // Check if already running
        if let app = findRunningApplication(normalizedName) {
            if app.activate() {
                return CommandResult(success: true, message: "Switched to \(appName)")
            }
        }
        
        // If not running, open it
        return try await openApplication(appName)
    }
    
    /// Hide an application
    private func hideApplication(_ appName: String) async throws -> CommandResult {
        let normalizedName = normalizeAppName(appName)
        
        guard let app = findRunningApplication(normalizedName) else {
            return CommandResult(success: false, message: "\(appName) is not running")
        }
        
        if app.hide() {
            return CommandResult(success: true, message: "Hidden \(appName)")
        }
        
        throw SystemControlError.executionFailed("Failed to hide \(appName)")
    }
    
    /// Show/unhide an application
    private func showApplication(_ appName: String) async throws -> CommandResult {
        let normalizedName = normalizeAppName(appName)
        
        guard let app = findRunningApplication(normalizedName) else {
            return CommandResult(success: false, message: "\(appName) is not running")
        }
        
        if app.unhide() && app.activate() {
            return CommandResult(success: true, message: "Shown \(appName)")
        }
        
        throw SystemControlError.executionFailed("Failed to show \(appName)")
    }
    
    // MARK: - Helper Methods
    
    /// Find application URL by name
    private func findApplication(_ name: String) -> URL? {
        // First try exact match
        if let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.\(name.lowercased())") {
            return url
        }
        
        // Try common bundle ID patterns
        let bundlePatterns = [
            "com.apple.\(name.lowercased())",
            "com.microsoft.\(name.lowercased())",
            "com.google.\(name.lowercased())",
            "com.\(name.lowercased()).\(name.lowercased())",
            "org.mozilla.\(name.lowercased())"
        ]
        
        for pattern in bundlePatterns {
            if let url = workspace.urlForApplication(withBundleIdentifier: pattern) {
                return url
            }
        }
        
        // Try to find by app name
        let appName = name.hasSuffix(".app") ? name : "\(name).app"
        
        // Search in Applications folder
        let applicationsFolders = [
            "/Applications",
            "/System/Applications",
            "~/Applications",
            "/Applications/Utilities"
        ].map { NSString(string: $0).expandingTildeInPath }
        
        for folder in applicationsFolders {
            let appPath = "\(folder)/\(appName)"
            if FileManager.default.fileExists(atPath: appPath) {
                return URL(fileURLWithPath: appPath)
            }
        }
        
        return nil
    }
    
    /// Find running application by name
    private func findRunningApplication(_ name: String) -> NSRunningApplication? {
        let runningApps = workspace.runningApplications
        
        // Try exact match first
        if let app = runningApps.first(where: { 
            $0.localizedName?.lowercased() == name.lowercased() ||
            $0.bundleIdentifier?.lowercased().contains(name.lowercased()) == true
        }) {
            return app
        }
        
        // Try partial match
        return runningApps.first(where: {
            $0.localizedName?.lowercased().contains(name.lowercased()) == true
        })
    }
    
    /// Normalize application name
    private func normalizeAppName(_ name: String) -> String {
        return name
            .replacingOccurrences(of: ".app", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Get common variations of app names
    private func getAppNameVariations(_ name: String) -> [String] {
        let base = name.lowercased()
        var variations = [base]
        
        // Common app name mappings
        let mappings: [String: [String]] = [
            "chrome": ["Google Chrome", "Chrome"],
            "safari": ["Safari", "Safari Technology Preview"],
            "firefox": ["Firefox", "Mozilla Firefox"],
            "mail": ["Mail", "Apple Mail"],
            "messages": ["Messages", "iMessage"],
            "calendar": ["Calendar", "iCal"],
            "terminal": ["Terminal", "iTerm", "iTerm2"],
            "code": ["Visual Studio Code", "VSCode", "Code"],
            "xcode": ["Xcode", "Xcode-beta"],
            "slack": ["Slack", "Slack Beta"],
            "spotify": ["Spotify", "Spotify Music"],
            "word": ["Microsoft Word", "Word"],
            "excel": ["Microsoft Excel", "Excel"],
            "powerpoint": ["Microsoft PowerPoint", "PowerPoint"],
            "photoshop": ["Adobe Photoshop", "Photoshop", "Adobe Photoshop 2024"],
            "illustrator": ["Adobe Illustrator", "Illustrator"],
            "finder": ["Finder"],
            "preview": ["Preview"],
            "notes": ["Notes", "Apple Notes"],
            "reminders": ["Reminders"],
            "music": ["Music", "Apple Music", "iTunes"]
        ]
        
        if let mapped = mappings[base] {
            variations.append(contentsOf: mapped)
        }
        
        // Add capitalized version
        variations.append(name.capitalized)
        
        // Add with spaces between words
        let spaced = base.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        if spaced != base {
            variations.append(spaced)
        }
        
        return variations
    }
    
    // MARK: - Application Information
    
    /// Get list of running applications
    func getRunningApplications() -> [ApplicationInfo] {
        return workspace.runningApplications.compactMap { app in
            guard let name = app.localizedName else { return nil }
            
            return ApplicationInfo(
                name: name,
                bundleIdentifier: app.bundleIdentifier ?? "",
                processIdentifier: app.processIdentifier,
                isActive: app.isActive,
                isHidden: app.isHidden,
                icon: app.icon
            )
        }
    }
    
    /// Get list of installed applications
    func getInstalledApplications() -> [ApplicationInfo] {
        var applications: [ApplicationInfo] = []
        
        let folders = [
            "/Applications",
            "/System/Applications",
            NSString(string: "~/Applications").expandingTildeInPath
        ]
        
        for folder in folders {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: folder) {
                for item in contents where item.hasSuffix(".app") {
                    let appPath = "\(folder)/\(item)"
                    let appURL = URL(fileURLWithPath: appPath)
                    
                    if let bundle = Bundle(url: appURL),
                       let bundleId = bundle.bundleIdentifier,
                       let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                        
                        let info = ApplicationInfo(
                            name: appName,
                            bundleIdentifier: bundleId,
                            processIdentifier: 0,
                            isActive: false,
                            isHidden: false,
                            icon: workspace.icon(forFile: appPath)
                        )
                        applications.append(info)
                    }
                }
            }
        }
        
        return applications
    }
}

// MARK: - Application Info

struct ApplicationInfo {
    let name: String
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let isActive: Bool
    let isHidden: Bool
    let icon: NSImage?
}
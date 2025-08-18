import Foundation
import AppKit
import CoreGraphics

/// Manages window positioning and control
class WindowManager {
    
    /// Execute window management commands
    func execute(_ command: SystemCommand) async throws -> CommandResult {
        switch command.action {
        case .minimize:
            return try await minimizeWindow()
            
        case .maximize:
            return try await maximizeWindow()
            
        case .restore:
            return try await restoreWindow()
            
        case .arrange:
            return try await arrangeWindows(command)
            
        case .resize:
            return try await resizeWindow(command)
            
        case .position:
            return try await positionWindow(command)
            
        default:
            throw SystemControlError.unsupportedAction(command.action)
        }
    }
    
    /// Minimize current window
    private func minimizeWindow() async throws -> CommandResult {
        if let app = NSWorkspace.shared.frontmostApplication {
            let script = """
                tell application "System Events"
                    tell process "\(app.localizedName ?? "")"
                        set frontmost to true
                        click menu item "Minimize" of menu "Window" of menu bar 1
                    end tell
                end tell
            """
            
            try await runAppleScript(script)
            return CommandResult(success: true, message: "Minimized window")
        }
        
        throw SystemControlError.executionFailed("No active window to minimize")
    }
    
    /// Maximize current window
    private func maximizeWindow() async throws -> CommandResult {
        if let app = NSWorkspace.shared.frontmostApplication {
            let script = """
                tell application "System Events"
                    tell process "\(app.localizedName ?? "")"
                        set frontmost to true
                        click button 2 of window 1
                    end tell
                end tell
            """
            
            try await runAppleScript(script)
            return CommandResult(success: true, message: "Maximized window")
        }
        
        throw SystemControlError.executionFailed("No active window to maximize")
    }
    
    /// Restore window from minimized state
    private func restoreWindow() async throws -> CommandResult {
        let script = """
            tell application "System Events"
                set frontApp to name of first application process whose frontmost is true
                tell process frontApp
                    set frontmost to true
                    if (count of windows) > 0 then
                        set value of attribute "AXMinimized" of window 1 to false
                    end if
                end tell
            end tell
        """
        
        try await runAppleScript(script)
        return CommandResult(success: true, message: "Restored window")
    }
    
    /// Arrange windows in specific layout
    private func arrangeWindows(_ command: SystemCommand) async throws -> CommandResult {
        let arrangement = command.parameters["arrangement"] as? String ?? "tile"
        
        switch arrangement {
        case "tile":
            return try await tileWindows()
        case "cascade":
            return try await cascadeWindows()
        case "split":
            return try await splitScreen()
        default:
            return try await tileWindows()
        }
    }
    
    /// Tile all windows
    private func tileWindows() async throws -> CommandResult {
        guard let screen = NSScreen.main else {
            throw SystemControlError.executionFailed("No main screen found")
        }
        
        let visibleFrame = screen.visibleFrame
        let windows = getVisibleWindows()
        
        guard !windows.isEmpty else {
            return CommandResult(success: false, message: "No windows to arrange")
        }
        
        let cols = Int(ceil(sqrt(Double(windows.count))))
        let rows = Int(ceil(Double(windows.count) / Double(cols)))
        
        let windowWidth = visibleFrame.width / CGFloat(cols)
        let windowHeight = visibleFrame.height / CGFloat(rows)
        
        for (index, window) in windows.enumerated() {
            let col = index % cols
            let row = index / cols
            
            let x = visibleFrame.minX + CGFloat(col) * windowWidth
            let y = visibleFrame.minY + CGFloat(row) * windowHeight
            
            try await positionWindow(window, at: CGPoint(x: x, y: y), size: CGSize(width: windowWidth, height: windowHeight))
        }
        
        return CommandResult(success: true, message: "Tiled \(windows.count) windows")
    }
    
    /// Cascade windows
    private func cascadeWindows() async throws -> CommandResult {
        guard let screen = NSScreen.main else {
            throw SystemControlError.executionFailed("No main screen found")
        }
        
        let windows = getVisibleWindows()
        let offset: CGFloat = 30
        var position = CGPoint(x: 100, y: 100)
        
        for window in windows {
            try await positionWindow(window, at: position, size: nil)
            position.x += offset
            position.y += offset
            
            // Reset if going off screen
            if position.x > screen.frame.width - 400 || position.y > screen.frame.height - 400 {
                position = CGPoint(x: 100, y: 100)
            }
        }
        
        return CommandResult(success: true, message: "Cascaded \(windows.count) windows")
    }
    
    /// Split screen between two windows
    private func splitScreen() async throws -> CommandResult {
        let windows = getVisibleWindows()
        
        guard windows.count >= 2 else {
            return CommandResult(success: false, message: "Need at least 2 windows for split screen")
        }
        
        guard let screen = NSScreen.main else {
            throw SystemControlError.executionFailed("No main screen found")
        }
        
        let visibleFrame = screen.visibleFrame
        let halfWidth = visibleFrame.width / 2
        
        // Position first window on left
        try await positionWindow(
            windows[0],
            at: CGPoint(x: visibleFrame.minX, y: visibleFrame.minY),
            size: CGSize(width: halfWidth, height: visibleFrame.height)
        )
        
        // Position second window on right
        try await positionWindow(
            windows[1],
            at: CGPoint(x: visibleFrame.minX + halfWidth, y: visibleFrame.minY),
            size: CGSize(width: halfWidth, height: visibleFrame.height)
        )
        
        return CommandResult(success: true, message: "Split screen activated")
    }
    
    /// Resize current window
    private func resizeWindow(_ command: SystemCommand) async throws -> CommandResult {
        let width = command.parameters["width"] as? CGFloat ?? 800
        let height = command.parameters["height"] as? CGFloat ?? 600
        
        if let app = NSWorkspace.shared.frontmostApplication {
            let script = """
                tell application "System Events"
                    tell process "\(app.localizedName ?? "")"
                        set frontmost to true
                        set size of window 1 to {\(width), \(height)}
                    end tell
                end tell
            """
            
            try await runAppleScript(script)
            return CommandResult(success: true, message: "Resized window to \(width)x\(height)")
        }
        
        throw SystemControlError.executionFailed("No active window to resize")
    }
    
    /// Position current window
    private func positionWindow(_ command: SystemCommand) async throws -> CommandResult {
        let position = command.parameters["position"] as? String ?? "center"
        
        guard let screen = NSScreen.main else {
            throw SystemControlError.executionFailed("No main screen found")
        }
        
        let visibleFrame = screen.visibleFrame
        var targetPosition: CGPoint
        
        switch position {
        case "center":
            targetPosition = CGPoint(
                x: visibleFrame.midX - 400,
                y: visibleFrame.midY - 300
            )
        case "top-left":
            targetPosition = CGPoint(x: visibleFrame.minX, y: visibleFrame.maxY - 600)
        case "top-right":
            targetPosition = CGPoint(x: visibleFrame.maxX - 800, y: visibleFrame.maxY - 600)
        case "bottom-left":
            targetPosition = CGPoint(x: visibleFrame.minX, y: visibleFrame.minY)
        case "bottom-right":
            targetPosition = CGPoint(x: visibleFrame.maxX - 800, y: visibleFrame.minY)
        default:
            targetPosition = CGPoint(x: visibleFrame.midX - 400, y: visibleFrame.midY - 300)
        }
        
        if let app = NSWorkspace.shared.frontmostApplication {
            let script = """
                tell application "System Events"
                    tell process "\(app.localizedName ?? "")"
                        set frontmost to true
                        set position of window 1 to {\(targetPosition.x), \(targetPosition.y)}
                    end tell
                end tell
            """
            
            try await runAppleScript(script)
            return CommandResult(success: true, message: "Positioned window at \(position)")
        }
        
        throw SystemControlError.executionFailed("No active window to position")
    }
    
    // MARK: - Helper Methods
    
    /// Get list of visible windows
    private func getVisibleWindows() -> [WindowInfo] {
        var windows: [WindowInfo] = []
        
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let appName = app.localizedName else { continue }
            
            // Get windows for this app using accessibility API
            // This is simplified - actual implementation would use AX API
            windows.append(WindowInfo(
                appName: appName,
                pid: app.processIdentifier,
                title: "",
                bounds: CGRect.zero
            ))
        }
        
        return windows
    }
    
    /// Position a specific window
    private func positionWindow(_ window: WindowInfo, at position: CGPoint, size: CGSize?) async throws {
        var script = """
            tell application "System Events"
                tell process id \(window.pid)
                    set position of window 1 to {\(position.x), \(position.y)}
        """
        
        if let size = size {
            script += """
                    set size of window 1 to {\(size.width), \(size.height)}
            """
        }
        
        script += """
                end tell
            end tell
        """
        
        try await runAppleScript(script)
    }
    
    /// Run AppleScript
    private func runAppleScript(_ script: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: script) {
                    scriptObject.executeAndReturnError(&error)
                    
                    if let error = error {
                        continuation.resume(throwing: SystemControlError.executionFailed(
                            error["NSAppleScriptErrorMessage"] as? String ?? "AppleScript error"
                        ))
                    } else {
                        continuation.resume()
                    }
                } else {
                    continuation.resume(throwing: SystemControlError.executionFailed("Invalid AppleScript"))
                }
            }
        }
    }
}

// MARK: - Window Info

struct WindowInfo {
    let appName: String
    let pid: pid_t
    let title: String
    let bounds: CGRect
}
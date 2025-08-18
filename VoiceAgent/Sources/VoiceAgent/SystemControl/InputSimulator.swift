import Foundation
import CoreGraphics
import Carbon.HIToolbox

/// Simulates keyboard and mouse input for system control
class InputSimulator {
    
    /// Execute input-related commands
    func execute(_ command: SystemCommand) async throws -> CommandResult {
        switch command.action {
        case .click:
            let clickType = command.parameters["type"] as? String ?? "left"
            return try await performClick(type: clickType)
            
        case .rightClick:
            return try await performClick(type: "right")
            
        case .doubleClick:
            return try await performClick(type: "double")
            
        case .drag:
            let startX = command.parameters["startX"] as? CGFloat ?? 0
            let startY = command.parameters["startY"] as? CGFloat ?? 0
            let endX = command.parameters["endX"] as? CGFloat ?? 100
            let endY = command.parameters["endY"] as? CGFloat ?? 100
            return try await performDrag(from: CGPoint(x: startX, y: startY), to: CGPoint(x: endX, y: endY))
            
        case .type:
            let text = command.parameters["text"] as? String ?? ""
            return try await typeText(text)
            
        case .pressKey:
            let keyCode = command.parameters["keyCode"] as? CGKeyCode ?? 0
            let modifiers = command.parameters["modifiers"] as? [ModifierKey] ?? []
            return try await pressKey(keyCode, modifiers: modifiers)
            
        default:
            throw SystemControlError.unsupportedAction(command.action)
        }
    }
    
    // MARK: - Mouse Control
    
    /// Perform mouse click
    private func performClick(type: String) async throws -> CommandResult {
        let location = getCurrentMouseLocation()
        
        switch type {
        case "left":
            simulateMouseClick(at: location, button: .left)
            return CommandResult(success: true, message: "Left clicked at \(location)")
            
        case "right":
            simulateMouseClick(at: location, button: .right)
            return CommandResult(success: true, message: "Right clicked at \(location)")
            
        case "double":
            simulateMouseClick(at: location, button: .left, clickCount: 2)
            return CommandResult(success: true, message: "Double clicked at \(location)")
            
        case "middle":
            simulateMouseClick(at: location, button: .center)
            return CommandResult(success: true, message: "Middle clicked at \(location)")
            
        default:
            throw SystemControlError.executionFailed("Unknown click type: \(type)")
        }
    }
    
    /// Simulate mouse click at location
    private func simulateMouseClick(at point: CGPoint, button: CGMouseButton, clickCount: Int = 1) {
        guard let mouseDownEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseEventType(for: button, isDown: true),
            mouseCursorPosition: point,
            mouseButton: button
        ) else { return }
        
        guard let mouseUpEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseEventType(for: button, isDown: false),
            mouseCursorPosition: point,
            mouseButton: button
        ) else { return }
        
        mouseDownEvent.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        mouseUpEvent.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        
        for _ in 0..<clickCount {
            mouseDownEvent.post(tap: .cghidEventTap)
            usleep(50000) // 50ms between down and up
            mouseUpEvent.post(tap: .cghidEventTap)
            
            if clickCount > 1 {
                usleep(100000) // 100ms between clicks for multi-click
            }
        }
    }
    
    /// Get mouse event type for button and state
    private func mouseEventType(for button: CGMouseButton, isDown: Bool) -> CGEventType {
        switch button {
        case .left:
            return isDown ? .leftMouseDown : .leftMouseUp
        case .right:
            return isDown ? .rightMouseDown : .rightMouseUp
        case .center:
            return isDown ? .otherMouseDown : .otherMouseUp
        @unknown default:
            return isDown ? .leftMouseDown : .leftMouseUp
        }
    }
    
    /// Move mouse to location
    func moveMouse(to point: CGPoint) async throws {
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            throw SystemControlError.executionFailed("Failed to create mouse move event")
        }
        
        moveEvent.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
    }
    
    /// Perform drag operation
    private func performDrag(from start: CGPoint, to end: CGPoint) async throws -> CommandResult {
        // Move to start position
        try await moveMouse(to: start)
        
        // Mouse down
        guard let mouseDown = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: start,
            mouseButton: .left
        ) else {
            throw SystemControlError.executionFailed("Failed to create drag start event")
        }
        
        mouseDown.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        
        // Drag to end position
        guard let mouseDrag = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDragged,
            mouseCursorPosition: end,
            mouseButton: .left
        ) else {
            throw SystemControlError.executionFailed("Failed to create drag event")
        }
        
        mouseDrag.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        
        // Mouse up
        guard let mouseUp = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: end,
            mouseButton: .left
        ) else {
            throw SystemControlError.executionFailed("Failed to create drag end event")
        }
        
        mouseUp.post(tap: .cghidEventTap)
        
        return CommandResult(success: true, message: "Dragged from \(start) to \(end)")
    }
    
    /// Get current mouse location
    private func getCurrentMouseLocation() -> CGPoint {
        return NSEvent.mouseLocation
    }
    
    /// Scroll in direction
    func scroll(direction: String, amount: Int) async throws {
        let scrollAmount: Int32
        
        switch direction {
        case "up":
            scrollAmount = Int32(amount)
        case "down":
            scrollAmount = -Int32(amount)
        case "left":
            scrollAmount = Int32(amount)
        case "right":
            scrollAmount = -Int32(amount)
        default:
            scrollAmount = -Int32(amount)
        }
        
        guard let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: scrollAmount,
            wheel2: 0,
            wheel3: 0
        ) else {
            throw SystemControlError.executionFailed("Failed to create scroll event")
        }
        
        scrollEvent.post(tap: .cghidEventTap)
    }
    
    // MARK: - Keyboard Control
    
    /// Type text string
    private func typeText(_ text: String) async throws -> CommandResult {
        for character in text {
            try await typeCharacter(character)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms between characters
        }
        
        return CommandResult(success: true, message: "Typed: \(text)")
    }
    
    /// Type a single character
    private func typeCharacter(_ character: Character) async throws {
        let string = String(character)
        
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            throw SystemControlError.executionFailed("Failed to create keyboard event")
        }
        
        keyDownEvent.keyboardSetUnicodeString(stringLength: string.count, unicodeString: string)
        keyUpEvent.keyboardSetUnicodeString(stringLength: string.count, unicodeString: string)
        
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }
    
    /// Press a specific key with modifiers
    func pressKey(_ keyCode: CGKeyCode, modifiers: [ModifierKey] = []) async throws {
        // Press modifiers
        for modifier in modifiers {
            pressModifier(modifier, down: true)
        }
        
        // Press key
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw SystemControlError.executionFailed("Failed to create key event")
        }
        
        // Apply modifiers to events
        var flags = CGEventFlags()
        for modifier in modifiers {
            flags.insert(modifier.cgEventFlag)
        }
        keyDown.flags = flags
        keyUp.flags = flags
        
        keyDown.post(tap: .cghidEventTap)
        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        keyUp.post(tap: .cghidEventTap)
        
        // Release modifiers
        for modifier in modifiers.reversed() {
            pressModifier(modifier, down: false)
        }
    }
    
    /// Press or release modifier key
    private func pressModifier(_ modifier: ModifierKey, down: Bool) {
        let keyCode = modifier.keyCode
        
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down) else {
            return
        }
        
        event.flags = down ? modifier.cgEventFlag : []
        event.post(tap: .cghidEventTap)
    }
    
    /// Simulate keyboard shortcut
    func pressShortcut(_ shortcut: String) async throws {
        let parts = shortcut.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        
        var modifiers: [ModifierKey] = []
        var keyCode: CGKeyCode?
        
        for part in parts {
            switch part {
            case "cmd", "command":
                modifiers.append(.command)
            case "ctrl", "control":
                modifiers.append(.control)
            case "opt", "option", "alt":
                modifiers.append(.option)
            case "shift":
                modifiers.append(.shift)
            case "fn", "function":
                modifiers.append(.function)
            default:
                keyCode = keyCodeForCharacter(part)
            }
        }
        
        if let key = keyCode {
            try await pressKey(key, modifiers: modifiers)
        }
    }
    
    /// Get key code for character
    private func keyCodeForCharacter(_ char: String) -> CGKeyCode? {
        let keyMap: [String: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
            "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23,
            "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35,
            "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42,
            ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
            "space": 49, "`": 50,
            "delete": 51, "return": 36, "tab": 48, "escape": 53,
            "right": 124, "left": 123, "down": 125, "up": 126,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111
        ]
        
        return keyMap[char.lowercased()]
    }
}

// MARK: - Modifier Keys

enum ModifierKey {
    case command
    case control
    case option
    case shift
    case function
    case capsLock
    
    var keyCode: CGKeyCode {
        switch self {
        case .command: return 55
        case .control: return 59
        case .option: return 58
        case .shift: return 56
        case .function: return 63
        case .capsLock: return 57
        }
    }
    
    var cgEventFlag: CGEventFlags {
        switch self {
        case .command: return .maskCommand
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .shift: return .maskShift
        case .function: return .maskSecondaryFn
        case .capsLock: return .maskAlphaShift
        }
    }
}

// MARK: - Key Codes Extension

extension CGKeyCode {
    static let a: CGKeyCode = 0
    static let s: CGKeyCode = 1
    static let d: CGKeyCode = 2
    static let f: CGKeyCode = 3
    static let h: CGKeyCode = 4
    static let g: CGKeyCode = 5
    static let z: CGKeyCode = 6
    static let x: CGKeyCode = 7
    static let c: CGKeyCode = 8
    static let v: CGKeyCode = 9
    static let b: CGKeyCode = 11
    static let q: CGKeyCode = 12
    static let w: CGKeyCode = 13
    static let e: CGKeyCode = 14
    static let r: CGKeyCode = 15
    static let y: CGKeyCode = 16
    static let t: CGKeyCode = 17
    static let one: CGKeyCode = 18
    static let two: CGKeyCode = 19
    static let three: CGKeyCode = 20
    static let four: CGKeyCode = 21
    static let six: CGKeyCode = 22
    static let five: CGKeyCode = 23
    static let equals: CGKeyCode = 24
    static let nine: CGKeyCode = 25
    static let seven: CGKeyCode = 26
    static let minus: CGKeyCode = 27
    static let eight: CGKeyCode = 28
    static let zero: CGKeyCode = 29
    static let rightBracket: CGKeyCode = 30
    static let o: CGKeyCode = 31
    static let u: CGKeyCode = 32
    static let leftBracket: CGKeyCode = 33
    static let i: CGKeyCode = 34
    static let p: CGKeyCode = 35
    static let returnKey: CGKeyCode = 36
    static let l: CGKeyCode = 37
    static let j: CGKeyCode = 38
    static let quote: CGKeyCode = 39
    static let k: CGKeyCode = 40
    static let semicolon: CGKeyCode = 41
    static let backslash: CGKeyCode = 42
    static let comma: CGKeyCode = 43
    static let slash: CGKeyCode = 44
    static let n: CGKeyCode = 45
    static let m: CGKeyCode = 46
    static let period: CGKeyCode = 47
    static let tab: CGKeyCode = 48
    static let space: CGKeyCode = 49
    static let grave: CGKeyCode = 50
    static let delete: CGKeyCode = 51
    static let escape: CGKeyCode = 53
    static let rightArrow: CGKeyCode = 124
    static let leftArrow: CGKeyCode = 123
    static let downArrow: CGKeyCode = 125
    static let upArrow: CGKeyCode = 126
}
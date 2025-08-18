import Foundation
import ApplicationServices
import AppKit

/// Bridge for accessibility API interactions
class AccessibilityBridge {
    
    /// Execute accessibility commands
    func execute(_ command: SystemCommand) async throws -> CommandResult {
        guard AXIsProcessTrusted() else {
            throw SystemControlError.permissionDenied(.accessibility)
        }
        
        switch command.action {
        case .custom(let action):
            return try await executeCustomAction(action, parameters: command.parameters)
        default:
            return try await performAccessibilityAction(command)
        }
    }
    
    /// Perform accessibility action on UI element
    private func performAccessibilityAction(_ command: SystemCommand) async throws -> CommandResult {
        guard let app = getFrontmostApplication() else {
            throw SystemControlError.executionFailed("No frontmost application")
        }
        
        let element = try findUIElement(in: app, matching: command.target)
        
        switch command.action {
        case .click:
            try performClick(on: element)
            return CommandResult(success: true, message: "Clicked on \(command.target)")
            
        default:
            throw SystemControlError.unsupportedAction(command.action)
        }
    }
    
    /// Execute custom accessibility action
    private func executeCustomAction(_ action: String, parameters: [String: Any]) async throws -> CommandResult {
        switch action {
        case "click_button":
            return try await clickButton(named: parameters["name"] as? String ?? "")
            
        case "select_menu":
            return try await selectMenuItem(parameters["menu"] as? String ?? "", 
                                           item: parameters["item"] as? String ?? "")
            
        case "focus_field":
            return try await focusTextField(parameters["field"] as? String ?? "")
            
        case "read_text":
            return try await readText(from: parameters["element"] as? String ?? "")
            
        case "get_ui_tree":
            return try await getUITree()
            
        default:
            throw SystemControlError.unsupportedAction(.custom(action))
        }
    }
    
    // MARK: - UI Element Actions
    
    /// Click a button by name
    private func clickButton(named name: String) async throws -> CommandResult {
        guard let app = getFrontmostApplication() else {
            throw SystemControlError.executionFailed("No frontmost application")
        }
        
        let buttons = findButtons(in: app)
        
        for button in buttons {
            if let title = getTitle(of: button), title.lowercased().contains(name.lowercased()) {
                try performClick(on: button)
                return CommandResult(success: true, message: "Clicked button: \(title)")
            }
        }
        
        throw SystemControlError.executionFailed("Button '\(name)' not found")
    }
    
    /// Select menu item
    private func selectMenuItem(_ menu: String, item: String) async throws -> CommandResult {
        guard let app = getFrontmostApplication() else {
            throw SystemControlError.executionFailed("No frontmost application")
        }
        
        guard let menuBar = getMenuBar(of: app) else {
            throw SystemControlError.executionFailed("Menu bar not found")
        }
        
        let menuItems = getMenuItems(from: menuBar)
        
        for menuItem in menuItems {
            if let title = getTitle(of: menuItem), title.lowercased().contains(menu.lowercased()) {
                // Open menu
                try performAction(kAXPressAction, on: menuItem)
                
                // Find and click item
                let subItems = getChildren(of: menuItem)
                for subItem in subItems {
                    if let itemTitle = getTitle(of: subItem), itemTitle.lowercased().contains(item.lowercased()) {
                        try performClick(on: subItem)
                        return CommandResult(success: true, message: "Selected menu item: \(menu) > \(item)")
                    }
                }
            }
        }
        
        throw SystemControlError.executionFailed("Menu item not found")
    }
    
    /// Focus a text field
    private func focusTextField(_ fieldName: String) async throws -> CommandResult {
        guard let app = getFrontmostApplication() else {
            throw SystemControlError.executionFailed("No frontmost application")
        }
        
        let textFields = findTextFields(in: app)
        
        for field in textFields {
            if let description = getDescription(of: field), 
               description.lowercased().contains(fieldName.lowercased()) {
                try setFocused(field, focused: true)
                return CommandResult(success: true, message: "Focused field: \(fieldName)")
            }
        }
        
        throw SystemControlError.executionFailed("Text field '\(fieldName)' not found")
    }
    
    /// Read text from UI element
    private func readText(from elementName: String) async throws -> CommandResult {
        guard let app = getFrontmostApplication() else {
            throw SystemControlError.executionFailed("No frontmost application")
        }
        
        let elements = findAllElements(in: app)
        
        for element in elements {
            if let description = getDescription(of: element),
               description.lowercased().contains(elementName.lowercased()) {
                if let value = getValue(of: element) as? String {
                    return CommandResult(
                        success: true,
                        message: "Read text from \(elementName)",
                        output: ["text": value]
                    )
                }
            }
        }
        
        throw SystemControlError.executionFailed("Element '\(elementName)' not found")
    }
    
    /// Get UI tree of current application
    private func getUITree() async throws -> CommandResult {
        guard let app = getFrontmostApplication() else {
            throw SystemControlError.executionFailed("No frontmost application")
        }
        
        let tree = buildUITree(from: app, depth: 0, maxDepth: 3)
        
        return CommandResult(
            success: true,
            message: "Retrieved UI tree",
            output: ["tree": tree]
        )
    }
    
    // MARK: - Helper Methods
    
    /// Get frontmost application
    private func getFrontmostApplication() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AXUIElementCreateApplication(app.processIdentifier)
    }
    
    /// Find UI element matching criteria
    private func findUIElement(in app: AXUIElement, matching criteria: String) throws -> AXUIElement {
        let elements = findAllElements(in: app)
        
        for element in elements {
            if let description = getDescription(of: element),
               description.lowercased().contains(criteria.lowercased()) {
                return element
            }
            
            if let title = getTitle(of: element),
               title.lowercased().contains(criteria.lowercased()) {
                return element
            }
        }
        
        throw SystemControlError.executionFailed("UI element '\(criteria)' not found")
    }
    
    /// Find all elements in application
    private func findAllElements(in app: AXUIElement) -> [AXUIElement] {
        var elements: [AXUIElement] = []
        
        if let windows = getWindows(of: app) {
            for window in windows {
                elements.append(contentsOf: getAllChildren(of: window))
            }
        }
        
        return elements
    }
    
    /// Get all children of element recursively
    private func getAllChildren(of element: AXUIElement) -> [AXUIElement] {
        var allChildren: [AXUIElement] = [element]
        let children = getChildren(of: element)
        
        for child in children {
            allChildren.append(contentsOf: getAllChildren(of: child))
        }
        
        return allChildren
    }
    
    /// Get children of element
    private func getChildren(of element: AXUIElement) -> [AXUIElement] {
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success, let childArray = children as? [AXUIElement] else {
            return []
        }
        
        return childArray
    }
    
    /// Get windows of application
    private func getWindows(of app: AXUIElement) -> [AXUIElement]? {
        var windows: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)
        
        guard result == .success else { return nil }
        return windows as? [AXUIElement]
    }
    
    /// Get menu bar of application
    private func getMenuBar(of app: AXUIElement) -> AXUIElement? {
        var menuBar: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBar)
        
        guard result == .success else { return nil }
        return (menuBar as! AXUIElement)
    }
    
    /// Get menu items from menu bar
    private func getMenuItems(from menuBar: AXUIElement) -> [AXUIElement] {
        return getChildren(of: menuBar)
    }
    
    /// Find buttons in application
    private func findButtons(in app: AXUIElement) -> [AXUIElement] {
        return findAllElements(in: app).filter { getRole(of: $0) == kAXButtonRole }
    }
    
    /// Find text fields in application
    private func findTextFields(in app: AXUIElement) -> [AXUIElement] {
        return findAllElements(in: app).filter { 
            let role = getRole(of: $0)
            return role == kAXTextFieldRole || role == kAXTextAreaRole
        }
    }
    
    /// Get role of element
    private func getRole(of element: AXUIElement) -> String? {
        var role: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        guard result == .success else { return nil }
        return role as? String
    }
    
    /// Get title of element
    private func getTitle(of element: AXUIElement) -> String? {
        var title: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        
        guard result == .success else { return nil }
        return title as? String
    }
    
    /// Get description of element
    private func getDescription(of element: AXUIElement) -> String? {
        var description: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)
        
        guard result == .success else { return nil }
        return description as? String
    }
    
    /// Get value of element
    private func getValue(of element: AXUIElement) -> Any? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        guard result == .success else { return nil }
        return value
    }
    
    /// Perform click on element
    private func performClick(on element: AXUIElement) throws {
        try performAction(kAXPressAction, on: element)
    }
    
    /// Perform action on element
    private func performAction(_ action: String, on element: AXUIElement) throws {
        let result = AXUIElementPerformAction(element, action as CFString)
        
        guard result == .success else {
            throw SystemControlError.executionFailed("Failed to perform action: \(action)")
        }
    }
    
    /// Set focused state of element
    private func setFocused(_ element: AXUIElement, focused: Bool) throws {
        let result = AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, focused as CFBoolean)
        
        guard result == .success else {
            throw SystemControlError.executionFailed("Failed to set focus")
        }
    }
    
    /// Build UI tree representation
    private func buildUITree(from element: AXUIElement, depth: Int, maxDepth: Int) -> [String: Any] {
        guard depth < maxDepth else { return [:] }
        
        var tree: [String: Any] = [:]
        
        if let role = getRole(of: element) {
            tree["role"] = role
        }
        
        if let title = getTitle(of: element) {
            tree["title"] = title
        }
        
        if let description = getDescription(of: element) {
            tree["description"] = description
        }
        
        let children = getChildren(of: element)
        if !children.isEmpty {
            tree["children"] = children.map { buildUITree(from: $0, depth: depth + 1, maxDepth: maxDepth) }
        }
        
        return tree
    }
}
import Foundation
import AppKit

/// Controls file system operations
class FileSystemController {
    private let fileManager = FileManager.default
    
    /// Execute file system commands
    func execute(_ command: SystemCommand) async throws -> CommandResult {
        switch command.action {
        case .createFolder:
            return try await createFolder(command)
            
        case .createFile:
            return try await createFile(command)
            
        case .delete:
            return try await deleteItem(command)
            
        case .move:
            return try await moveItem(command)
            
        case .copy:
            return try await copyItem(command)
            
        case .rename:
            return try await renameItem(command)
            
        default:
            throw SystemControlError.unsupportedAction(command.action)
        }
    }
    
    /// Create a new folder
    private func createFolder(_ command: SystemCommand) async throws -> CommandResult {
        let basePath = expandPath(command.target)
        let folderName = command.parameters["name"] as? String ?? "New Folder"
        let fullPath = "\(basePath)/\(folderName)"
        
        do {
            try fileManager.createDirectory(
                atPath: fullPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Open in Finder
            NSWorkspace.shared.selectFile(fullPath, inFileViewerRootedAtPath: basePath)
            
            return CommandResult(
                success: true,
                message: "Created folder: \(folderName)",
                output: ["path": fullPath]
            )
        } catch {
            throw SystemControlError.executionFailed("Failed to create folder: \(error.localizedDescription)")
        }
    }
    
    /// Create a new file
    private func createFile(_ command: SystemCommand) async throws -> CommandResult {
        let basePath = expandPath(command.target)
        let fileName = command.parameters["name"] as? String ?? "New File.txt"
        let content = command.parameters["content"] as? String ?? ""
        let fullPath = "\(basePath)/\(fileName)"
        
        do {
            let data = content.data(using: .utf8) ?? Data()
            let success = fileManager.createFile(atPath: fullPath, contents: data, attributes: nil)
            
            if success {
                // Open in default application
                NSWorkspace.shared.open(URL(fileURLWithPath: fullPath))
                
                return CommandResult(
                    success: true,
                    message: "Created file: \(fileName)",
                    output: ["path": fullPath]
                )
            } else {
                throw SystemControlError.executionFailed("Failed to create file")
            }
        } catch {
            throw SystemControlError.executionFailed("Failed to create file: \(error.localizedDescription)")
        }
    }
    
    /// Delete file or folder
    private func deleteItem(_ command: SystemCommand) async throws -> CommandResult {
        let path = expandPath(command.target)
        
        guard fileManager.fileExists(atPath: path) else {
            throw SystemControlError.fileNotFound(path)
        }
        
        // Move to trash instead of permanent deletion
        do {
            var trashedItemURL: NSURL?
            try fileManager.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: &trashedItemURL)
            
            return CommandResult(
                success: true,
                message: "Moved to trash: \(URL(fileURLWithPath: path).lastPathComponent)",
                output: ["trashedPath": trashedItemURL?.path ?? ""]
            )
        } catch {
            throw SystemControlError.executionFailed("Failed to delete: \(error.localizedDescription)")
        }
    }
    
    /// Move file or folder
    private func moveItem(_ command: SystemCommand) async throws -> CommandResult {
        let sourcePath = expandPath(command.target)
        let destinationPath = expandPath(command.parameters["destination"] as? String ?? "")
        
        guard fileManager.fileExists(atPath: sourcePath) else {
            throw SystemControlError.fileNotFound(sourcePath)
        }
        
        do {
            try fileManager.moveItem(atPath: sourcePath, toPath: destinationPath)
            
            return CommandResult(
                success: true,
                message: "Moved item to: \(destinationPath)",
                output: ["newPath": destinationPath]
            )
        } catch {
            throw SystemControlError.executionFailed("Failed to move: \(error.localizedDescription)")
        }
    }
    
    /// Copy file or folder
    private func copyItem(_ command: SystemCommand) async throws -> CommandResult {
        let sourcePath = expandPath(command.target)
        let destinationPath = expandPath(command.parameters["destination"] as? String ?? "")
        
        guard fileManager.fileExists(atPath: sourcePath) else {
            throw SystemControlError.fileNotFound(sourcePath)
        }
        
        do {
            try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
            
            return CommandResult(
                success: true,
                message: "Copied item to: \(destinationPath)",
                output: ["copiedPath": destinationPath]
            )
        } catch {
            throw SystemControlError.executionFailed("Failed to copy: \(error.localizedDescription)")
        }
    }
    
    /// Rename file or folder
    private func renameItem(_ command: SystemCommand) async throws -> CommandResult {
        let sourcePath = expandPath(command.target)
        let newName = command.parameters["newName"] as? String ?? ""
        
        guard fileManager.fileExists(atPath: sourcePath) else {
            throw SystemControlError.fileNotFound(sourcePath)
        }
        
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destinationURL = sourceURL.deletingLastPathComponent().appendingPathComponent(newName)
        
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            
            return CommandResult(
                success: true,
                message: "Renamed to: \(newName)",
                output: ["newPath": destinationURL.path]
            )
        } catch {
            throw SystemControlError.executionFailed("Failed to rename: \(error.localizedDescription)")
        }
    }
    
    /// Open file or folder in Finder
    func openInFinder(_ path: String) async throws -> CommandResult {
        let expandedPath = expandPath(path)
        
        guard fileManager.fileExists(atPath: expandedPath) else {
            throw SystemControlError.fileNotFound(expandedPath)
        }
        
        NSWorkspace.shared.selectFile(expandedPath, inFileViewerRootedAtPath: "")
        
        return CommandResult(
            success: true,
            message: "Opened in Finder: \(expandedPath)"
        )
    }
    
    /// Get file information
    func getFileInfo(_ path: String) async throws -> FileInfo {
        let expandedPath = expandPath(path)
        
        guard fileManager.fileExists(atPath: expandedPath) else {
            throw SystemControlError.fileNotFound(expandedPath)
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: expandedPath)
        let url = URL(fileURLWithPath: expandedPath)
        
        return FileInfo(
            path: expandedPath,
            name: url.lastPathComponent,
            size: attributes[.size] as? Int64 ?? 0,
            createdDate: attributes[.creationDate] as? Date,
            modifiedDate: attributes[.modificationDate] as? Date,
            isDirectory: (attributes[.type] as? FileAttributeType) == .typeDirectory,
            isHidden: url.lastPathComponent.hasPrefix(".")
        )
    }
    
    /// Search for files
    func searchFiles(query: String, in directory: String? = nil) async throws -> [String] {
        let searchPath = expandPath(directory ?? "~")
        var results: [String] = []
        
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: searchPath),
            includingPropertiesForKeys: [.nameKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent.lowercased().contains(query.lowercased()) {
                results.append(fileURL.path)
                
                // Limit results
                if results.count >= 20 {
                    break
                }
            }
        }
        
        return results
    }
    
    // MARK: - Helper Methods
    
    /// Expand tilde and resolve path
    private func expandPath(_ path: String) -> String {
        var expandedPath = path
        
        // Handle special folders
        let specialFolders: [String: String] = [
            "desktop": "~/Desktop",
            "documents": "~/Documents",
            "downloads": "~/Downloads",
            "applications": "/Applications",
            "home": "~",
            "trash": "~/.Trash"
        ]
        
        for (key, value) in specialFolders {
            if path.lowercased() == key {
                expandedPath = value
                break
            }
        }
        
        // Expand tilde
        expandedPath = NSString(string: expandedPath).expandingTildeInPath
        
        // If no path specified, use Desktop
        if expandedPath.isEmpty {
            expandedPath = NSString(string: "~/Desktop").expandingTildeInPath
        }
        
        return expandedPath
    }
}

// MARK: - File Info

struct FileInfo {
    let path: String
    let name: String
    let size: Int64
    let createdDate: Date?
    let modifiedDate: Date?
    let isDirectory: Bool
    let isHidden: Bool
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
//
//  SaveState.swift
//  NesCaster
//
//  Data model for save states with stack-based history
//

import Foundation
import SwiftUI

// MARK: - Save State Entry

/// Represents a single save state with metadata and screenshot
struct SaveStateEntry: Identifiable, Codable {
    let id: UUID
    let gameID: String              // ROM hash/filename identifier
    let profileID: UUID
    let timestamp: Date
    let metadata: SaveMetadata
    
    // File paths (relative to saves directory)
    var stateFileName: String { "\(id.uuidString).state" }
    var screenshotFileName: String { "\(id.uuidString).png" }
    
    init(gameID: String, profileID: UUID, metadata: SaveMetadata) {
        self.id = UUID()
        self.gameID = gameID
        self.profileID = profileID
        self.timestamp = Date()
        self.metadata = metadata
    }
}

// MARK: - Save Metadata

/// Additional information about the save state
struct SaveMetadata: Codable {
    var gameName: String
    var playTime: TimeInterval      // Total play time at save
    var levelHint: String?          // "World 3-2" if detectable
    var isAutoSave: Bool
    var frameCount: UInt64          // Frame number at save
    
    init(gameName: String, playTime: TimeInterval = 0, levelHint: String? = nil, isAutoSave: Bool = false, frameCount: UInt64 = 0) {
        self.gameName = gameName
        self.playTime = playTime
        self.levelHint = levelHint
        self.isAutoSave = isAutoSave
        self.frameCount = frameCount
    }
}

// MARK: - Save State Stack

/// Stack of save states for a single game, maintaining history
struct SaveStateStack: Codable {
    let gameID: String
    let profileID: UUID
    var entries: [SaveStateEntry]
    var maxSize: Int
    
    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }
    var latest: SaveStateEntry? { entries.first }
    
    init(gameID: String, profileID: UUID, maxSize: Int = 5) {
        self.gameID = gameID
        self.profileID = profileID
        self.entries = []
        self.maxSize = maxSize
    }
    
    /// Push a new save state, removing oldest if at capacity
    mutating func push(_ entry: SaveStateEntry) -> SaveStateEntry? {
        // Insert at beginning (newest first)
        entries.insert(entry, at: 0)
        
        // Remove oldest if over capacity
        if entries.count > maxSize {
            return entries.removeLast()
        }
        return nil
    }
    
    /// Get entry at index (0 = newest)
    func entry(at index: Int) -> SaveStateEntry? {
        guard index >= 0 && index < entries.count else { return nil }
        return entries[index]
    }
    
    /// Remove a specific entry
    mutating func remove(id: UUID) -> SaveStateEntry? {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            return entries.remove(at: index)
        }
        return nil
    }
    
    /// Clear all entries
    mutating func clear() -> [SaveStateEntry] {
        let removed = entries
        entries.removeAll()
        return removed
    }
}

// MARK: - Auto Save Settings

/// Configuration for automatic save states
struct AutoSaveSettings: Codable {
    var enabled: Bool
    var onLevelComplete: Bool
    var intervalMinutes: Int        // 0 = disabled
    var separateFromManual: Bool    // Don't count toward stack limit
    
    static let `default` = AutoSaveSettings(
        enabled: true,
        onLevelComplete: true,
        intervalMinutes: 5,
        separateFromManual: true
    )
}

// MARK: - Save State Result

/// Result of a save/load operation
enum SaveStateResult {
    case success(SaveStateEntry)
    case failure(SaveStateError)
}

enum SaveStateError: Error, LocalizedError {
    case noActiveGame
    case noActiveProfile
    case saveFailed(String)
    case loadFailed(String)
    case stackEmpty
    case entryNotFound
    case fileSystemError(String)
    
    var errorDescription: String? {
        switch self {
        case .noActiveGame: return "No game is currently running"
        case .noActiveProfile: return "No profile is selected"
        case .saveFailed(let msg): return "Save failed: \(msg)"
        case .loadFailed(let msg): return "Load failed: \(msg)"
        case .stackEmpty: return "No save states available"
        case .entryNotFound: return "Save state not found"
        case .fileSystemError(let msg): return "File error: \(msg)"
        }
    }
}


//
//  SaveStateManager.swift
//  NesCaster
//
//  Manages save state stacks with history for each game
//

import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
class SaveStateManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentStack: SaveStateStack?
    @Published private(set) var isLoading = false
    @Published private(set) var lastSaveTime: Date?
    @Published var autoSaveSettings: AutoSaveSettings
    
    // MARK: - Configuration
    
    @AppStorage("saveStateHistorySize") private var historySize: Int = 5
    
    // MARK: - Private Properties
    
    private var stacks: [String: SaveStateStack] = [:]  // gameID -> stack
    private var autoSaveTimer: Timer?
    private let fileManager = FileManager.default
    
    // MARK: - Dependencies
    
    private weak var emulatorCore: NESEmulatorCore?
    private var profileManager: ProfileManager?
    
    // MARK: - Singleton
    
    static let shared = SaveStateManager()
    
    private init() {
        self.autoSaveSettings = AutoSaveSettings.default
        loadAutoSaveSettings()
    }
    
    // MARK: - Setup
    
    func configure(emulatorCore: NESEmulatorCore, profileManager: ProfileManager) {
        self.emulatorCore = emulatorCore
        self.profileManager = profileManager
    }
    
    // MARK: - Stack Management
    
    /// Load or create stack for a game
    func loadStack(gameID: String, profileID: UUID) {
        let key = stackKey(gameID: gameID, profileID: profileID)
        
        if let existingStack = stacks[key] {
            currentStack = existingStack
            return
        }
        
        // Try to load from disk
        if let loadedStack = loadStackFromDisk(gameID: gameID, profileID: profileID) {
            stacks[key] = loadedStack
            currentStack = loadedStack
        } else {
            // Create new stack
            let newStack = SaveStateStack(gameID: gameID, profileID: profileID, maxSize: historySize)
            stacks[key] = newStack
            currentStack = newStack
        }
        
        startAutoSaveTimerIfNeeded()
    }
    
    /// Update history size for current stack
    func updateHistorySize(_ size: Int) {
        historySize = size
        if var stack = currentStack {
            stack.maxSize = size
            let key = stackKey(gameID: stack.gameID, profileID: stack.profileID)
            stacks[key] = stack
            currentStack = stack
        }
    }
    
    // MARK: - Save Operations
    
    /// Quick save to stack (instant, pushes to history)
    func quickSave(gameName: String, playTime: TimeInterval = 0, frameCount: UInt64 = 0) async -> SaveStateResult {
        guard let core = emulatorCore else {
            return .failure(.noActiveGame)
        }
        
        guard let profile = profileManager?.activeProfile else {
            return .failure(.noActiveProfile)
        }
        
        guard var stack = currentStack else {
            return .failure(.noActiveGame)
        }
        
        // Create metadata
        let metadata = SaveMetadata(
            gameName: gameName,
            playTime: playTime,
            levelHint: nil,
            isAutoSave: false,
            frameCount: frameCount
        )
        
        // Create entry
        let entry = SaveStateEntry(
            gameID: stack.gameID,
            profileID: profile.id,
            metadata: metadata
        )
        
        // Get save state data from emulator
        guard let stateData = core.createSaveState() else {
            return .failure(.saveFailed("Failed to capture emulator state"))
        }
        
        // Capture screenshot
        let screenshotData = core.captureScreenshot()
        
        // Save files
        do {
            try saveEntryToDisk(entry: entry, stateData: stateData, screenshotData: screenshotData, profileID: profile.id)
        } catch {
            return .failure(.fileSystemError(error.localizedDescription))
        }
        
        // Push to stack (may remove oldest)
        if let removedEntry = stack.push(entry) {
            // Clean up removed entry's files
            deleteEntryFiles(removedEntry, profileID: profile.id)
        }
        
        // Update stack
        let key = stackKey(gameID: stack.gameID, profileID: profile.id)
        stacks[key] = stack
        currentStack = stack
        lastSaveTime = Date()
        
        // Persist stack metadata
        saveStackToDisk(stack, profileID: profile.id)
        
        return .success(entry)
    }
    
    /// Auto-save (separate from manual saves if configured)
    func autoSave(gameName: String, playTime: TimeInterval = 0, frameCount: UInt64 = 0) async -> SaveStateResult {
        guard autoSaveSettings.enabled else {
            return .failure(.saveFailed("Auto-save is disabled"))
        }
        
        guard let core = emulatorCore else {
            return .failure(.noActiveGame)
        }
        
        guard let profile = profileManager?.activeProfile else {
            return .failure(.noActiveProfile)
        }
        
        guard var stack = currentStack else {
            return .failure(.noActiveGame)
        }
        
        let metadata = SaveMetadata(
            gameName: gameName,
            playTime: playTime,
            levelHint: "Auto-Save",
            isAutoSave: true,
            frameCount: frameCount
        )
        
        let entry = SaveStateEntry(
            gameID: stack.gameID,
            profileID: profile.id,
            metadata: metadata
        )
        
        guard let stateData = core.createSaveState() else {
            return .failure(.saveFailed("Failed to capture emulator state"))
        }
        
        let screenshotData = core.captureScreenshot()
        
        do {
            try saveEntryToDisk(entry: entry, stateData: stateData, screenshotData: screenshotData, profileID: profile.id)
        } catch {
            return .failure(.fileSystemError(error.localizedDescription))
        }
        
        // Only count toward stack if not separate
        if !autoSaveSettings.separateFromManual {
            if let removedEntry = stack.push(entry) {
                deleteEntryFiles(removedEntry, profileID: profile.id)
            }
            
            let key = stackKey(gameID: stack.gameID, profileID: profile.id)
            stacks[key] = stack
            currentStack = stack
            saveStackToDisk(stack, profileID: profile.id)
        }
        
        return .success(entry)
    }
    
    // MARK: - Load Operations
    
    /// Load most recent save state
    func quickLoad() async -> SaveStateResult {
        guard let entry = currentStack?.latest else {
            return .failure(.stackEmpty)
        }
        return await loadEntry(entry)
    }
    
    /// Load specific save state by index (0 = newest)
    func loadAtIndex(_ index: Int) async -> SaveStateResult {
        guard let entry = currentStack?.entry(at: index) else {
            return .failure(.entryNotFound)
        }
        return await loadEntry(entry)
    }
    
    /// Load specific save state entry
    func loadEntry(_ entry: SaveStateEntry) async -> SaveStateResult {
        guard let core = emulatorCore else {
            return .failure(.noActiveGame)
        }
        
        guard let profile = profileManager?.activeProfile else {
            return .failure(.noActiveProfile)
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Load state data from disk
        do {
            let stateData = try loadEntryFromDisk(entry: entry, profileID: profile.id)
            
            // Apply to emulator
            guard core.loadSaveState(stateData) else {
                return .failure(.loadFailed("Emulator rejected state data"))
            }
            
            return .success(entry)
        } catch {
            return .failure(.fileSystemError(error.localizedDescription))
        }
    }
    
    // MARK: - Screenshot Loading
    
    /// Load screenshot for an entry
    func loadScreenshot(for entry: SaveStateEntry) -> UIImage? {
        guard let profile = profileManager?.activeProfile else { return nil }
        
        let savesDir = getSavesDirectory(profileID: profile.id, gameID: entry.gameID)
        let screenshotURL = savesDir.appendingPathComponent(entry.screenshotFileName)
        
        guard let data = try? Data(contentsOf: screenshotURL) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - Auto-Save Timer
    
    private func startAutoSaveTimerIfNeeded() {
        stopAutoSaveTimer()
        
        guard autoSaveSettings.enabled && autoSaveSettings.intervalMinutes > 0 else { return }
        
        let interval = TimeInterval(autoSaveSettings.intervalMinutes * 60)
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let gameName = self.currentStack?.entries.first?.metadata.gameName {
                    _ = await self.autoSave(gameName: gameName)
                }
            }
        }
    }
    
    private func stopAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
    
    // MARK: - File System Operations
    
    private func getSavesDirectory(profileID: UUID, gameID: String) -> URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let profileDir = documentsURL
            .appendingPathComponent("Profiles")
            .appendingPathComponent(profileID.uuidString)
            .appendingPathComponent("Saves")
            .appendingPathComponent(gameID.replacingOccurrences(of: "/", with: "_"))
        
        try? fileManager.createDirectory(at: profileDir, withIntermediateDirectories: true)
        return profileDir
    }
    
    private func saveEntryToDisk(entry: SaveStateEntry, stateData: Data, screenshotData: Data?, profileID: UUID) throws {
        let savesDir = getSavesDirectory(profileID: profileID, gameID: entry.gameID)
        
        // Save state file
        let stateURL = savesDir.appendingPathComponent(entry.stateFileName)
        try stateData.write(to: stateURL)
        
        // Save screenshot
        if let screenshot = screenshotData {
            let screenshotURL = savesDir.appendingPathComponent(entry.screenshotFileName)
            try screenshot.write(to: screenshotURL)
        }
    }
    
    private func loadEntryFromDisk(entry: SaveStateEntry, profileID: UUID) throws -> Data {
        let savesDir = getSavesDirectory(profileID: profileID, gameID: entry.gameID)
        let stateURL = savesDir.appendingPathComponent(entry.stateFileName)
        return try Data(contentsOf: stateURL)
    }
    
    private func deleteEntryFiles(_ entry: SaveStateEntry, profileID: UUID) {
        let savesDir = getSavesDirectory(profileID: profileID, gameID: entry.gameID)
        
        let stateURL = savesDir.appendingPathComponent(entry.stateFileName)
        let screenshotURL = savesDir.appendingPathComponent(entry.screenshotFileName)
        
        try? fileManager.removeItem(at: stateURL)
        try? fileManager.removeItem(at: screenshotURL)
    }
    
    private func saveStackToDisk(_ stack: SaveStateStack, profileID: UUID) {
        let savesDir = getSavesDirectory(profileID: profileID, gameID: stack.gameID)
        let stackURL = savesDir.appendingPathComponent("stack.json")
        
        if let data = try? JSONEncoder().encode(stack) {
            try? data.write(to: stackURL)
        }
    }
    
    private func loadStackFromDisk(gameID: String, profileID: UUID) -> SaveStateStack? {
        let savesDir = getSavesDirectory(profileID: profileID, gameID: gameID)
        let stackURL = savesDir.appendingPathComponent("stack.json")
        
        guard let data = try? Data(contentsOf: stackURL),
              let stack = try? JSONDecoder().decode(SaveStateStack.self, from: data) else {
            return nil
        }
        return stack
    }
    
    private func stackKey(gameID: String, profileID: UUID) -> String {
        "\(profileID.uuidString)_\(gameID)"
    }
    
    // MARK: - Settings Persistence
    
    private func loadAutoSaveSettings() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let settingsURL = documentsURL.appendingPathComponent("autosave_settings.json")
        
        if let data = try? Data(contentsOf: settingsURL),
           let settings = try? JSONDecoder().decode(AutoSaveSettings.self, from: data) {
            autoSaveSettings = settings
        }
    }
    
    func saveAutoSaveSettings() {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let settingsURL = documentsURL.appendingPathComponent("autosave_settings.json")
        
        if let data = try? JSONEncoder().encode(autoSaveSettings) {
            try? data.write(to: settingsURL)
        }
    }
    
    // MARK: - Utility
    
    /// Get all entries for current game (for UI)
    var allEntries: [SaveStateEntry] {
        currentStack?.entries ?? []
    }
    
    /// Check if there are any saves
    var hasSaves: Bool {
        !(currentStack?.isEmpty ?? true)
    }
}


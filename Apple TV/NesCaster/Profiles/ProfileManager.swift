//
//  ProfileManager.swift
//  NesCaster
//
//  Manages profile creation, persistence, and switching
//

import Foundation
import SwiftUI
import Combine

// MARK: - Profile Manager

@MainActor
class ProfileManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var profiles: [Profile] = []
    @Published var activeProfile: Profile?
    @Published private(set) var isLoading = true
    
    // MARK: - Constants
    
    static let maxProfiles = 4
    
    private let profilesFileName = "profiles.json"
    private var profilesFileURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("Profiles/\(profilesFileName)")
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadProfiles()
        }
    }
    
    // MARK: - Profile CRUD
    
    /// Create a new profile
    func createProfile(name: String, pictureID: String = "default_player1") -> Profile? {
        guard profiles.count < Self.maxProfiles else {
            print("❌ Maximum profiles reached (\(Self.maxProfiles))")
            return nil
        }
        
        let profile = Profile(name: name, pictureID: pictureID)
        
        // Create profile directories
        createProfileDirectories(for: profile)
        
        // Create default settings
        saveSettings(ProfileSettings(), for: profile)
        
        // Create default controller mapping
        saveControllerMapping(ControllerMapping(profileID: profile.id), for: profile)
        
        profiles.append(profile)
        saveProfiles()
        
        print("✅ Created profile: \(profile.name)")
        return profile
    }
    
    /// Update an existing profile
    func updateProfile(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }
        
        profiles[index] = profile
        saveProfiles()
        
        if activeProfile?.id == profile.id {
            activeProfile = profile
        }
        
        print("✅ Updated profile: \(profile.name)")
    }
    
    /// Delete a profile and all its data
    func deleteProfile(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }
        
        // Delete profile directory
        do {
            try FileManager.default.removeItem(at: profile.baseDirectory)
            print("🗑️ Deleted profile directory: \(profile.baseDirectory.path)")
        } catch {
            print("⚠️ Failed to delete profile directory: \(error)")
        }
        
        profiles.remove(at: index)
        
        // If deleted active profile, clear it
        if activeProfile?.id == profile.id {
            activeProfile = nil
        }
        
        saveProfiles()
        print("✅ Deleted profile: \(profile.name)")
    }
    
    /// Switch to a profile
    func switchToProfile(_ profile: Profile) {
        guard profiles.contains(where: { $0.id == profile.id }) else {
            return
        }
        
        // Update last used time
        var updatedProfile = profile
        updatedProfile.lastUsedAt = Date()
        updateProfile(updatedProfile)
        
        activeProfile = updatedProfile
        print("👤 Switched to profile: \(profile.name)")
    }
    
    // MARK: - Profile Settings
    
    /// Load settings for a profile
    func loadSettings(for profile: Profile) -> ProfileSettings {
        do {
            let data = try Data(contentsOf: profile.settingsPath)
            return try JSONDecoder().decode(ProfileSettings.self, from: data)
        } catch {
            print("⚠️ Failed to load settings, using defaults: \(error)")
            return ProfileSettings()
        }
    }
    
    /// Save settings for a profile
    func saveSettings(_ settings: ProfileSettings, for profile: Profile) {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: profile.settingsPath)
        } catch {
            print("❌ Failed to save settings: \(error)")
        }
    }
    
    // MARK: - Controller Mapping
    
    /// Load controller mapping for a profile
    func loadControllerMapping(for profile: Profile) -> ControllerMapping {
        do {
            let data = try Data(contentsOf: profile.controllerMappingPath)
            return try JSONDecoder().decode(ControllerMapping.self, from: data)
        } catch {
            print("⚠️ Failed to load controller mapping, using defaults")
            return ControllerMapping(profileID: profile.id)
        }
    }
    
    /// Save controller mapping for a profile
    func saveControllerMapping(_ mapping: ControllerMapping, for profile: Profile) {
        do {
            let data = try JSONEncoder().encode(mapping)
            try data.write(to: profile.controllerMappingPath)
        } catch {
            print("❌ Failed to save controller mapping: \(error)")
        }
    }
    
    // MARK: - Persistence
    
    private func loadProfiles() async {
        isLoading = true
        
        // Ensure profiles directory exists
        let profilesDir = profilesFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)
        
        // Load profiles
        do {
            let data = try Data(contentsOf: profilesFileURL)
            profiles = try JSONDecoder().decode([Profile].self, from: data)
            print("📂 Loaded \(profiles.count) profiles")
        } catch {
            print("ℹ️ No existing profiles found, starting fresh")
            profiles = []
        }
        
        isLoading = false
    }
    
    private func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: profilesFileURL)
        } catch {
            print("❌ Failed to save profiles: \(error)")
        }
    }
    
    // MARK: - Directory Management
    
    private func createProfileDirectories(for profile: Profile) {
        let directories = [
            profile.baseDirectory,
            profile.romsDirectory,
            profile.savesDirectory,
            profile.autoSavesDirectory,
            profile.customPicturesDirectory
        ]
        
        for directory in directories {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                print("❌ Failed to create directory \(directory.path): \(error)")
            }
        }
        
        print("📁 Created directories for profile: \(profile.name)")
    }
    
    // MARK: - ROM Management
    
    /// Get all ROMs for a profile
    func getROMs(for profile: Profile) -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: profile.romsDirectory,
                includingPropertiesForKeys: nil
            )
            return contents.filter { $0.pathExtension.lowercased() == "nes" }
        } catch {
            return []
        }
    }
    
    /// Get ROM count for a profile
    func getROMCount(for profile: Profile) -> Int {
        return getROMs(for: profile).count
    }
    
    // MARK: - Helpers
    
    /// Check if a name is available
    func isNameAvailable(_ name: String, excluding profileID: UUID? = nil) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !profiles.contains { profile in
            profile.id != profileID && 
            profile.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmedName
        }
    }
    
    /// Get default picture ID for new profile
    func getDefaultPictureID() -> String {
        let usedPictures = Set(profiles.map { $0.pictureID })
        let defaults = ["default_player1", "default_player2", "default_player3", "default_player4"]
        
        for pictureID in defaults {
            if !usedPictures.contains(pictureID) {
                return pictureID
            }
        }
        
        return "default_player1"
    }
}


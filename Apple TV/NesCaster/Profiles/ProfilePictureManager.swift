//
//  ProfilePictureManager.swift
//  NesCaster
//
//  Manages profile picture library (static + animated)
//

import Foundation
import SwiftUI

// MARK: - Profile Picture Manager

@MainActor
class ProfilePictureManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var pictures: [ProfilePicture] = []
    @Published private(set) var categories: [ProfilePictureManifest.PictureCategory] = []
    @Published private(set) var isLoaded = false
    
    // MARK: - Singleton
    
    static let shared = ProfilePictureManager()
    
    // MARK: - Default Pictures (Built-in)
    
    private let defaultPictures: [ProfilePicture] = [
        ProfilePicture(id: "default_player1", name: "Player 1", type: .static, file: "", category: "default", color: "#E74C3C"),
        ProfilePicture(id: "default_player2", name: "Player 2", type: .static, file: "", category: "default", color: "#3498DB"),
        ProfilePicture(id: "default_player3", name: "Player 3", type: .static, file: "", category: "default", color: "#2ECC71"),
        ProfilePicture(id: "default_player4", name: "Player 4", type: .static, file: "", category: "default", color: "#9B59B6"),
    ]
    
    private let defaultCategories: [ProfilePictureManifest.PictureCategory] = [
        .init(id: "default", name: "Default", description: "Default player avatars"),
        .init(id: "retro", name: "Retro", description: "Classic gaming icons"),
        .init(id: "characters", name: "Characters", description: "Animated characters"),
        .init(id: "custom", name: "Custom", description: "Your uploaded pictures"),
    ]
    
    // MARK: - Initialization
    
    private init() {
        loadPictures()
    }
    
    // MARK: - Loading
    
    func loadPictures() {
        // Start with defaults
        pictures = defaultPictures
        categories = defaultCategories
        
        // Try to load from bundle manifest
        if let manifestURL = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "ProfilePictures") {
            do {
                let data = try Data(contentsOf: manifestURL)
                let manifest = try JSONDecoder().decode(ProfilePictureManifest.self, from: data)
                
                // Merge with defaults (don't replace defaults)
                for picture in manifest.pictures where !pictures.contains(where: { $0.id == picture.id }) {
                    pictures.append(picture)
                }
                
                for category in manifest.categories where !categories.contains(where: { $0.id == category.id }) {
                    categories.append(category)
                }
                
                print("📷 Loaded \(manifest.pictures.count) pictures from manifest")
            } catch {
                print("⚠️ Failed to load manifest: \(error)")
            }
        }
        
        isLoaded = true
    }
    
    // MARK: - Picture Access
    
    /// Get a picture by ID
    func getPicture(id: String) -> ProfilePicture? {
        pictures.first { $0.id == id }
    }
    
    /// Get pictures by category
    func getPictures(category: String) -> [ProfilePicture] {
        pictures.filter { $0.category == category }
    }
    
    /// Get the color for a picture (used for default avatars)
    func getColor(for pictureID: String) -> Color {
        guard let picture = getPicture(id: pictureID),
              let hexColor = picture.color else {
            return .gray
        }
        return Color(hex: hexColor) ?? .gray
    }
    
    // MARK: - Custom Pictures
    
    /// Add a custom picture for a profile
    func addCustomPicture(data: Data, name: String, to profile: Profile) -> ProfilePicture? {
        let pictureID = "custom_\(UUID().uuidString)"
        let fileName = "\(pictureID).png"
        let filePath = profile.customPicturesDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: filePath)
            
            let picture = ProfilePicture(
                id: pictureID,
                name: name,
                type: .static,
                file: filePath.path,
                category: "custom"
            )
            
            pictures.append(picture)
            return picture
            
        } catch {
            print("❌ Failed to save custom picture: \(error)")
            return nil
        }
    }
    
    /// Load custom pictures for a profile
    func loadCustomPictures(for profile: Profile) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: profile.customPicturesDirectory,
                includingPropertiesForKeys: nil
            )
            
            for fileURL in contents {
                let ext = fileURL.pathExtension.lowercased()
                guard ext == "png" || ext == "jpg" || ext == "jpeg" else { continue }
                
                let pictureID = fileURL.deletingPathExtension().lastPathComponent
                
                // Skip if already loaded
                guard !pictures.contains(where: { $0.id == pictureID }) else { continue }
                
                let picture = ProfilePicture(
                    id: pictureID,
                    name: fileURL.deletingPathExtension().lastPathComponent,
                    type: .static,
                    file: fileURL.path,
                    category: "custom"
                )
                
                pictures.append(picture)
            }
            
        } catch {
            print("⚠️ Failed to load custom pictures: \(error)")
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}


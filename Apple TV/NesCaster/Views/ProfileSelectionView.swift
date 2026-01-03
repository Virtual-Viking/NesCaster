//
//  ProfileSelectionView.swift
//  NesCaster
//
//  Netflix-style profile selection screen
//

import SwiftUI

struct ProfileSelectionView: View {
    
    @ObservedObject var profileManager: ProfileManager
    @State private var showingCreateProfile = false
    @State private var showingEditProfile = false
    @State private var profileToEdit: Profile?
    @State private var isManageMode = false
    
    var onProfileSelected: (Profile) -> Void
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Background
            backgroundGradient
            
            VStack(spacing: 60) {
                // Header
                headerView
                
                // Profile Grid
                profileGrid
                
                // Manage Button
                if !profileManager.profiles.isEmpty {
                    manageButton
                }
            }
            .padding(80)
        }
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView(profileManager: profileManager)
        }
        .sheet(item: $profileToEdit) { profile in
            EditProfileView(profileManager: profileManager, profile: profile)
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.06),
                    Color(red: 0.05, green: 0.03, blue: 0.1),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle animated glow
            RadialGradient(
                colors: [
                    Color(red: 0.9, green: 0.25, blue: 0.35).opacity(0.15),
                    Color.clear
                ],
                center: .top,
                startRadius: 100,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Text("Who's Playing?")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if isManageMode {
                Text("Select a profile to edit or delete")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    // MARK: - Profile Grid
    
    private var profileGrid: some View {
        HStack(spacing: 50) {
            // Existing profiles
            ForEach(profileManager.profiles) { profile in
                ProfileCard(
                    profile: profile,
                    isManageMode: isManageMode,
                    onSelect: {
                        if isManageMode {
                            profileToEdit = profile
                        } else {
                            onProfileSelected(profile)
                        }
                    }
                )
            }
            
            // Add profile button (if under limit)
            if profileManager.profiles.count < ProfileManager.maxProfiles && !isManageMode {
                AddProfileCard {
                    showingCreateProfile = true
                }
            }
        }
    }
    
    // MARK: - Manage Button
    
    private var manageButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                isManageMode.toggle()
            }
        }) {
            Text(isManageMode ? "Done" : "Manage Profiles")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Card

struct ProfileCard: View {
    let profile: Profile
    let isManageMode: Bool
    let onSelect: () -> Void
    
    @Environment(\.isFocused) var isFocused
    @StateObject private var pictureManager = ProfilePictureManager.shared
    
    private var profileColor: Color {
        pictureManager.getColor(for: profile.pictureID)
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 20) {
                // Avatar
                ZStack {
                    // Background circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    profileColor.opacity(0.8),
                                    profileColor.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                    
                    // Initial letter
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Edit indicator
                    if isManageMode {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 160, height: 160)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(
                            isFocused ? Color.white : Color.clear,
                            lineWidth: 4
                        )
                )
                .shadow(
                    color: isFocused ? profileColor.opacity(0.6) : .clear,
                    radius: 30
                )
                
                // Name
                Text(profile.name)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isFocused ? .white : .white.opacity(0.7))
                
                // Game count
                Text("\(getROMCount()) games")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.4))
            }
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isFocused)
        }
        .buttonStyle(.plain)
    }
    
    private func getROMCount() -> Int {
        // TODO: Get actual count from ProfileManager
        return 0
    }
}

// MARK: - Add Profile Card

struct AddProfileCard: View {
    let onTap: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 20) {
                // Plus icon
                ZStack {
                    Circle()
                        .stroke(
                            isFocused ? Color.white : Color.white.opacity(0.3),
                            lineWidth: 3
                        )
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(isFocused ? .white : .white.opacity(0.5))
                }
                .shadow(
                    color: isFocused ? Color.white.opacity(0.3) : .clear,
                    radius: 20
                )
                
                // Label
                Text("Add Profile")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isFocused ? .white : .white.opacity(0.5))
                
                // Spacer for alignment
                Text(" ")
                    .font(.system(size: 14))
                    .foregroundColor(.clear)
            }
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isFocused)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Create Profile View

struct CreateProfileView: View {
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var selectedPictureID: String
    @FocusState private var isNameFieldFocused: Bool
    
    init(profileManager: ProfileManager) {
        self.profileManager = profileManager
        _selectedPictureID = State(initialValue: profileManager.getDefaultPictureID())
    }
    
    private var isValidName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 1 && trimmed.count <= 20 && profileManager.isNameAvailable(trimmed)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
                
                VStack(spacing: 50) {
                    // Preview
                    profilePreview
                    
                    // Name input
                    VStack(spacing: 12) {
                        Text("Profile Name")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Enter name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .focused($isNameFieldFocused)
                            .frame(maxWidth: 400)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    
                    // Picture selection
                    pictureSelector
                    
                    // Create button
                    Button(action: createProfile) {
                        Text("Create Profile")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(isValidName ? Color(red: 0.9, green: 0.3, blue: 0.4) : Color.gray.opacity(0.3))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValidName)
                }
                .padding(60)
            }
            .navigationTitle("New Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
    }
    
    private var profilePreview: some View {
        let color = ProfilePictureManager.shared.getColor(for: selectedPictureID)
        
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.8), color.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
            
            Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .shadow(color: color.opacity(0.5), radius: 20)
    }
    
    private var pictureSelector: some View {
        VStack(spacing: 12) {
            Text("Choose Color")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(spacing: 20) {
                ForEach(["default_player1", "default_player2", "default_player3", "default_player4"], id: \.self) { pictureID in
                    let color = ProfilePictureManager.shared.getColor(for: pictureID)
                    
                    Button(action: { selectedPictureID = pictureID }) {
                        Circle()
                            .fill(color)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedPictureID == pictureID ? 3 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func createProfile() {
        guard isValidName else { return }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let profile = profileManager.createProfile(name: trimmedName, pictureID: selectedPictureID) {
            profileManager.switchToProfile(profile)
            dismiss()
        }
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @ObservedObject var profileManager: ProfileManager
    let profile: Profile
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String
    @State private var selectedPictureID: String
    @State private var showingDeleteConfirmation = false
    
    init(profileManager: ProfileManager, profile: Profile) {
        self.profileManager = profileManager
        self.profile = profile
        _name = State(initialValue: profile.name)
        _selectedPictureID = State(initialValue: profile.pictureID)
    }
    
    private var isValidName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 1 && trimmed.count <= 20 && profileManager.isNameAvailable(trimmed, excluding: profile.id)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
                
                VStack(spacing: 50) {
                    // Preview
                    profilePreview
                    
                    // Name input
                    VStack(spacing: 12) {
                        Text("Profile Name")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        
                        TextField("Enter name", text: $name)
                            .textFieldStyle(.plain)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 400)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                    
                    // Picture selection
                    pictureSelector
                    
                    // Buttons
                    HStack(spacing: 30) {
                        // Save button
                        Button(action: saveProfile) {
                            Text("Save Changes")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .fill(isValidName ? Color(red: 0.9, green: 0.3, blue: 0.4) : Color.gray.opacity(0.3))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!isValidName)
                        
                        // Delete button
                        Button(action: { showingDeleteConfirmation = true }) {
                            Text("Delete Profile")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule()
                                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(60)
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Delete Profile?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    profileManager.deleteProfile(profile)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete \"\(profile.name)\" and all saved games. This cannot be undone.")
            }
        }
    }
    
    private var profilePreview: some View {
        let color = ProfilePictureManager.shared.getColor(for: selectedPictureID)
        
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.8), color.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
            
            Text(name.isEmpty ? "?" : String(name.prefix(1)).uppercased())
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .shadow(color: color.opacity(0.5), radius: 20)
    }
    
    private var pictureSelector: some View {
        VStack(spacing: 12) {
            Text("Choose Color")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(spacing: 20) {
                ForEach(["default_player1", "default_player2", "default_player3", "default_player4"], id: \.self) { pictureID in
                    let color = ProfilePictureManager.shared.getColor(for: pictureID)
                    
                    Button(action: { selectedPictureID = pictureID }) {
                        Circle()
                            .fill(color)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedPictureID == pictureID ? 3 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func saveProfile() {
        guard isValidName else { return }
        
        var updatedProfile = profile
        updatedProfile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProfile.pictureID = selectedPictureID
        
        profileManager.updateProfile(updatedProfile)
        dismiss()
    }
}

#Preview {
    ProfileSelectionView(profileManager: ProfileManager()) { profile in
        print("Selected: \(profile.name)")
    }
}


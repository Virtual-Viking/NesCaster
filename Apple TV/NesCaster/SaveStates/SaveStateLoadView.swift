//
//  SaveStateLoadView.swift
//  NesCaster
//
//  Liquid Glass UI for loading save states with visual history
//

import SwiftUI
import UIKit

struct SaveStateLoadView: View {
    
    @ObservedObject var saveStateManager: SaveStateManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedIndex: Int = 0
    @State private var isLoading = false
    @State private var loadError: String?
    
    var onLoad: ((SaveStateEntry) -> Void)?
    var onCancel: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            // Glass container
            VStack(spacing: 0) {
                // Header
                glassHeader
                
                // Save state grid
                if saveStateManager.allEntries.isEmpty {
                    emptyState
                } else {
                    saveStateGrid
                }
                
                // Footer with instructions
                glassFooter
            }
            .frame(maxWidth: 1200, maxHeight: 700)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
            )
            
            // Loading overlay
            if isLoading {
                loadingOverlay
            }
        }
        .alert("Load Failed", isPresented: .init(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )) {
            Button("OK") { loadError = nil }
        } message: {
            Text(loadError ?? "Unknown error")
        }
    }
    
    // MARK: - Glass Header
    
    private var glassHeader: some View {
        HStack(spacing: 20) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.3))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(Color(red: 0.7, green: 0.5, blue: 0.9))
            }
            .shadow(color: Color(red: 0.7, green: 0.5, blue: 0.9).opacity(0.4), radius: 15)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Load Save State")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(saveStateManager.allEntries.count) saves available")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Close button
            Button(action: { onCancel?(); dismiss() }) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .background(Color.white.opacity(0.03))
    }
    
    // MARK: - Save State Grid
    
    private var saveStateGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(Array(saveStateManager.allEntries.enumerated()), id: \.element.id) { index, entry in
                    SaveStateCard(
                        entry: entry,
                        index: index,
                        isSelected: index == selectedIndex,
                        screenshot: saveStateManager.loadScreenshot(for: entry)
                    ) {
                        loadSaveState(entry)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .scrollClipDisabled()
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "square.stack.3d.up.slash")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.white.opacity(0.4))
            }
            
            Text("No Save States")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Press Save during gameplay to create a save point")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Glass Footer
    
    private var glassFooter: some View {
        HStack(spacing: 40) {
            HStack(spacing: 10) {
                Image(systemName: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill")
                    .font(.system(size: 14))
                Text("Navigate")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.5))
            
            HStack(spacing: 10) {
                Image(systemName: "a.circle.fill")
                    .font(.system(size: 14))
                Text("Load Selected")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.5))
            
            HStack(spacing: 10) {
                Image(systemName: "b.circle.fill")
                    .font(.system(size: 14))
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            if let entry = saveStateManager.allEntries.first {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: .green, radius: 4)
                    
                    Text("Latest: \(entry.timestamp.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(24)
        .background(Color.white.opacity(0.03))
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text("Loading State...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Actions
    
    private func loadSaveState(_ entry: SaveStateEntry) {
        isLoading = true
        
        Task {
            let result = await saveStateManager.loadEntry(entry)
            
            await MainActor.run {
                isLoading = false
                
                switch result {
                case .success(let loadedEntry):
                    onLoad?(loadedEntry)
                    dismiss()
                case .failure(let error):
                    loadError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Save State Card

struct SaveStateCard: View {
    let entry: SaveStateEntry
    let index: Int
    let isSelected: Bool
    let screenshot: UIImage?
    let onSelect: () -> Void
    
    @Environment(\.isFocused) var isFocused
    
    private var accentColor: Color {
        entry.metadata.isAutoSave 
            ? Color(red: 0.4, green: 0.7, blue: 0.9)
            : Color(red: 0.7, green: 0.5, blue: 0.9)
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 16) {
                // Screenshot with glass frame
                ZStack {
                    // Glass background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(accentColor.opacity(0.15))
                        )
                    
                    // Screenshot or placeholder
                    if let screenshot = screenshot {
                        Image(uiImage: screenshot)
                            .resizable()
                            .aspectRatio(256/240, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(8)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "photo")
                                .font(.system(size: 36, weight: .light))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text("No Preview")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    
                    // Slot badge
                    VStack {
                        HStack {
                            Text(index == 0 ? "★ Latest" : "Slot \(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Group {
                                        if index == 0 {
                                            Capsule().fill(Color.green.opacity(0.8))
                                        } else {
                                            Capsule().fill(.ultraThinMaterial)
                                        }
                                    }
                                )
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(10)
                    
                    // Auto-save badge
                    if entry.metadata.isAutoSave {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.cyan)
                                    .shadow(color: .cyan.opacity(0.5), radius: 5)
                            }
                            Spacer()
                        }
                        .padding(10)
                    }
                }
                .frame(width: 280, height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isFocused
                                ? LinearGradient(colors: [accentColor.opacity(0.9), accentColor.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isFocused ? 3 : 1
                        )
                )
                .shadow(
                    color: isFocused ? accentColor.opacity(0.5) : .clear,
                    radius: 20
                )
                
                // Info
                VStack(spacing: 6) {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let hint = entry.metadata.levelHint {
                        Text(hint)
                            .font(.system(size: 13))
                            .foregroundColor(accentColor)
                    }
                    
                    Text(formatPlayTime(entry.metadata.playTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isFocused)
        }
        .buttonStyle(.plain)
    }
    
    private func formatPlayTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Save Toast

struct SaveToastView: View {
    let slotNumber: Int
    let totalSlots: Int
    
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("State Saved!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Slot \(slotNumber) of \(totalSlots)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.green.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: .green.opacity(0.3), radius: 20)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = false
                    }
                }
            }
        }
    }
}

#Preview {
    SaveStateLoadView(saveStateManager: SaveStateManager.shared)
        .preferredColorScheme(.dark)
}


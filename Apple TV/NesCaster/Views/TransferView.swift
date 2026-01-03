//
//  TransferView.swift
//  NesCaster
//
//  Liquid Glass UI for content transfer via web server
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct TransferView: View {
    
    @ObservedObject var transferServer: ContentTransferServer
    @ObservedObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    
    @State private var animateQR = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Glass background
                liquidGlassBackground
                
                if transferServer.isRunning {
                    serverActiveView
                } else {
                    serverInactiveView
                }
            }
            .navigationTitle("Add Content")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        transferServer.stop()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                transferServer.stop()
            }
        }
    }
    
    // MARK: - Liquid Glass Background
    
    private var liquidGlassBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.08),
                    Color(red: 0.05, green: 0.04, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Accent orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.3, green: 0.7, blue: 0.9).opacity(0.3), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .blur(radius: 80)
                .offset(x: -200, y: -200)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.5, green: 0.3, blue: 0.8).opacity(0.25), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .blur(radius: 60)
                .offset(x: 200, y: 200)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Server Active View
    
    private var serverActiveView: some View {
        VStack(spacing: 40) {
            // QR Code section
            qrCodeSection
            
            // Instructions
            instructionsSection
            
            // Status
            statusSection
        }
        .padding(50)
    }
    
    // MARK: - QR Code Section
    
    private var qrCodeSection: some View {
        VStack(spacing: 24) {
            // QR Code with glass frame
            ZStack {
                // Glass backing
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .frame(width: 320, height: 320)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 15)
                
                // QR Code
                if let address = transferServer.serverAddress {
                    let url = "http://\(address):\(transferServer.port)"
                    
                    if let qrImage = generateQRCode(from: url) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 260, height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .scaleEffect(animateQR ? 1.0 : 0.95)
                            .opacity(animateQR ? 1.0 : 0.8)
                            .onAppear {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                    animateQR = true
                                }
                            }
                    }
                }
            }
            
            // URL display
            if let address = transferServer.serverAddress {
                VStack(spacing: 8) {
                    Text("Open in browser:")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("http://\(address):\(transferServer.port)")
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
    
    // MARK: - Instructions Section
    
    private var instructionsSection: some View {
        VStack(spacing: 16) {
            Text("How to Transfer Files")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 30) {
                InstructionStep(number: 1, text: "Connect to same\nWi-Fi network")
                InstructionStep(number: 2, text: "Scan QR code\nor enter URL")
                InstructionStep(number: 3, text: "Upload .nes\nROM files")
            }
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        HStack(spacing: 24) {
            // Server status
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .shadow(color: .green, radius: 5)
                
                Text("Server Active")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.15))
            )
            
            // Connected clients
            HStack(spacing: 10) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14))
                
                Text("\(transferServer.connectedClients) connected")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial.opacity(0.5))
            )
            
            // Last upload
            if let lastFile = transferServer.lastUploadedFile {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Last: \(lastFile)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.3))
                )
            }
        }
    }
    
    // MARK: - Server Inactive View
    
    private var serverInactiveView: some View {
        VStack(spacing: 40) {
            // Icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 140, height: 140)
                
                Image(systemName: "wifi")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 0.7, blue: 0.9), Color(red: 0.5, green: 0.3, blue: 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: Color(red: 0.3, green: 0.7, blue: 0.9).opacity(0.3), radius: 25)
            
            VStack(spacing: 16) {
                Text("Start Transfer Server")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Upload ROMs from your phone or computer")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Button(action: startServer) {
                HStack(spacing: 14) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18))
                    
                    Text("Start Server")
                        .font(.system(size: 20, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.3, green: 0.7, blue: 0.9), Color(red: 0.5, green: 0.3, blue: 0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Color(red: 0.3, green: 0.7, blue: 0.9).opacity(0.4), radius: 20)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(50)
    }
    
    // MARK: - Actions
    
    private func startServer() {
        guard let profile = profileManager.activeProfile else { return }
        
        do {
            try transferServer.start(for: profile.id)
        } catch {
            print("❌ Failed to start server: \(error)")
        }
    }
    
    // MARK: - QR Code Generation
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale up for clarity
        let scale = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: scale)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Instruction Step

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                
                Text("\(number)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 0.7, blue: 0.9), Color(red: 0.5, green: 0.3, blue: 0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    TransferView(
        transferServer: ContentTransferServer.shared,
        profileManager: ProfileManager()
    )
    .preferredColorScheme(.dark)
}


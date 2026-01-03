//
//  PerformanceOverlayView.swift
//  NesCaster
//
//  Real-time performance metrics overlay with Liquid Glass styling
//  Shows FPS, frame time, latency, and system stats
//

import SwiftUI

// MARK: - Performance Data

struct PerformanceData: Equatable {
    var fps: Double = 0
    var frameTimeMs: Double = 0
    var renderTimeMs: Double = 0
    var inputLatencyMs: Double = 0
    var audioLatencyMs: Double = 0
    var runAheadFrames: Int = 0
    var cpuUsage: Double = 0
    var memoryUsageMB: Double = 0
    var scalingMode: String = "Integer"
    var resolution: String = "1920x1080"
    
    var totalLatencyMs: Double {
        frameTimeMs + inputLatencyMs + audioLatencyMs
    }
}

// MARK: - Performance Overlay View

struct PerformanceOverlayView: View {
    let data: PerformanceData
    @Binding var isVisible: Bool
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Spacer()
            
            if isVisible {
                VStack(alignment: .trailing, spacing: 8) {
                    // Collapse/Expand button
                    Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    
                    if isExpanded {
                        expandedView
                    } else {
                        compactView
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding()
    }
    
    // MARK: - Compact View
    
    private var compactView: some View {
        HStack(spacing: 16) {
            // FPS indicator
            fpsIndicator
            
            // Frame time
            MetricBadge(
                value: String(format: "%.1f", data.frameTimeMs),
                unit: "ms",
                color: frameTimeColor
            )
            
            // Total latency
            MetricBadge(
                value: String(format: "%.0f", data.totalLatencyMs),
                unit: "ms lat",
                color: latencyColor
            )
        }
    }
    
    // MARK: - Expanded View
    
    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("PERFORMANCE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            
            Divider().background(Color.white.opacity(0.2))
            
            // Main metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(title: "FPS", value: String(format: "%.1f", data.fps), color: fpsColor)
                MetricCard(title: "Frame", value: String(format: "%.2f ms", data.frameTimeMs), color: frameTimeColor)
                MetricCard(title: "Render", value: String(format: "%.2f ms", data.renderTimeMs), color: .cyan)
                MetricCard(title: "Total Lat", value: String(format: "%.1f ms", data.totalLatencyMs), color: latencyColor)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // Detailed breakdown
            VStack(alignment: .leading, spacing: 6) {
                DetailRow(label: "Input Latency", value: String(format: "%.1f ms", data.inputLatencyMs))
                DetailRow(label: "Audio Latency", value: String(format: "%.1f ms", data.audioLatencyMs))
                DetailRow(label: "Run-Ahead", value: data.runAheadFrames > 0 ? "\(data.runAheadFrames) frames" : "Off")
                DetailRow(label: "Scaling", value: data.scalingMode)
                DetailRow(label: "Resolution", value: data.resolution)
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            // System stats
            VStack(alignment: .leading, spacing: 6) {
                DetailRow(label: "CPU", value: String(format: "%.1f%%", data.cpuUsage))
                DetailRow(label: "Memory", value: String(format: "%.1f MB", data.memoryUsageMB))
            }
        }
        .frame(width: 240)
    }
    
    // MARK: - FPS Indicator
    
    private var fpsIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(fpsColor)
                .frame(width: 8, height: 8)
            
            Text(String(format: "%.0f", data.fps))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Text("FPS")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Colors
    
    private var fpsColor: Color {
        if data.fps >= 59 { return .green }
        if data.fps >= 50 { return .yellow }
        return .red
    }
    
    private var frameTimeColor: Color {
        if data.frameTimeMs <= 16.67 { return .green }
        if data.frameTimeMs <= 20 { return .yellow }
        return .red
    }
    
    private var latencyColor: Color {
        if data.totalLatencyMs <= 50 { return .green }
        if data.totalLatencyMs <= 100 { return .yellow }
        return .orange
    }
}

// MARK: - Metric Badge

struct MetricBadge: View {
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
            
            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.3))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PerformanceOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            PerformanceOverlayView(
                data: PerformanceData(
                    fps: 59.94,
                    frameTimeMs: 16.67,
                    renderTimeMs: 2.5,
                    inputLatencyMs: 16.67,
                    audioLatencyMs: 21.0,
                    runAheadFrames: 2,
                    cpuUsage: 35.5,
                    memoryUsageMB: 128.5,
                    scalingMode: "Integer 8x",
                    resolution: "3840x2160"
                ),
                isVisible: .constant(true)
            )
        }
    }
}
#endif


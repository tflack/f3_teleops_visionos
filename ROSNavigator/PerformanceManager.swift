//
//  PerformanceManager.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class PerformanceManager: ObservableObject {
    @Published var currentMetrics = PerformanceMetrics()
    @Published var isOptimizationActive = false
    @Published var optimizationLevel: OptimizationLevel = .balanced
    
    enum OptimizationLevel {
        case performance
        case balanced
        case quality
        
        var displayName: String {
            switch self {
            case .performance: return "Performance"
            case .balanced: return "Balanced"
            case .quality: return "Quality"
            }
        }
    }
    
    struct PerformanceMetrics {
        var fps: Double = 60.0
        var memoryUsage: Double = 0.0
        var cpuUsage: Double = 0.0
        var networkLatency: Double = 0.0
        var frameTime: Double = 16.67 // 60 FPS = 16.67ms per frame
        var renderTime: Double = 0.0
        var updateTime: Double = 0.0
        var lastUpdate: Date = Date()
        
        var isPerformanceGood: Bool {
            return fps >= 30.0 && memoryUsage < 500.0 && cpuUsage < 80.0
        }
        
        var performanceScore: Double {
            let fpsScore = min(fps / 60.0, 1.0) * 0.4
            let memoryScore = max(0, (1000.0 - memoryUsage) / 1000.0) * 0.3
            let cpuScore = max(0, (100.0 - cpuUsage) / 100.0) * 0.3
            return (fpsScore + memoryScore + cpuScore) * 100.0
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var performanceTimer: Timer?
    private var frameTimeTracker: FrameTimeTracker?
    
    // Performance thresholds
    private let lowFPSThreshold: Double = 30.0
    private let highMemoryThreshold: Double = 500.0 // MB
    private let highCPUThreshold: Double = 80.0 // %
    private let highLatencyThreshold: Double = 100.0 // ms
    
    init() {
        setupPerformanceMonitoring()
        frameTimeTracker = FrameTimeTracker()
    }
    
    deinit {
        performanceTimer?.invalidate()
    }
    
    // MARK: - Performance Monitoring
    
    private func setupPerformanceMonitoring() {
        // Monitor performance every second
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePerformanceMetrics()
            }
        }
        
        // Monitor frame times
        frameTimeTracker?.onFrameTimeUpdate = { [weak self] frameTime in
            Task { @MainActor [weak self] in
                self?.currentMetrics.frameTime = frameTime
                self?.currentMetrics.fps = 1000.0 / frameTime
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // Update memory usage
        currentMetrics.memoryUsage = getMemoryUsage()
        
        // Update CPU usage
        currentMetrics.cpuUsage = getCPUUsage()
        
        // Update network latency
        currentMetrics.networkLatency = getNetworkLatency()
        
        // Update timestamp
        currentMetrics.lastUpdate = Date()
        
        // Check if optimization is needed
        checkPerformanceThresholds()
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0.0
    }
    
    private func getCPUUsage() -> Double {
        // Simplified CPU usage calculation for visionOS
        // In a real implementation, you would use ProcessInfo or other system APIs
        // For now, return a simulated value
        return Double.random(in: 10...80)
    }
    
    private func getNetworkLatency() -> Double {
        // Simulate network latency measurement
        // In a real implementation, this would ping the robot
        return 50.0 // Placeholder
    }
    
    // MARK: - Performance Optimization
    
    private func checkPerformanceThresholds() {
        let needsOptimization = currentMetrics.fps < lowFPSThreshold ||
                               currentMetrics.memoryUsage > highMemoryThreshold ||
                               currentMetrics.cpuUsage > highCPUThreshold ||
                               currentMetrics.networkLatency > highLatencyThreshold
        
        if needsOptimization && !isOptimizationActive {
            activateOptimization()
        } else if !needsOptimization && isOptimizationActive {
            deactivateOptimization()
        }
    }
    
    func activateOptimization() {
        isOptimizationActive = true
        applyOptimizations()
    }
    
    func deactivateOptimization() {
        isOptimizationActive = false
        removeOptimizations()
    }
    
    private func applyOptimizations() {
        switch optimizationLevel {
        case .performance:
            applyPerformanceOptimizations()
        case .balanced:
            applyBalancedOptimizations()
        case .quality:
            applyQualityOptimizations()
        }
    }
    
    private func applyPerformanceOptimizations() {
        // Aggressive performance optimizations
        // - Reduce frame rate to 30 FPS
        // - Lower video quality
        // - Disable non-essential visualizations
        // - Reduce update frequency
        
        print("🚀 Applying performance optimizations")
    }
    
    private func applyBalancedOptimizations() {
        // Balanced optimizations
        // - Reduce frame rate to 45 FPS
        // - Moderate video quality reduction
        // - Keep essential visualizations
        // - Moderate update frequency reduction
        
        print("⚖️ Applying balanced optimizations")
    }
    
    private func applyQualityOptimizations() {
        // Minimal optimizations to maintain quality
        // - Keep 60 FPS
        // - Maintain video quality
        // - Keep all visualizations
        // - Minimal update frequency reduction
        
        print("🎨 Applying quality optimizations")
    }
    
    private func removeOptimizations() {
        // Remove all optimizations and restore normal performance
        print("🔄 Removing performance optimizations")
    }
    
    // MARK: - Optimization Controls
    
    func setOptimizationLevel(_ level: OptimizationLevel) {
        optimizationLevel = level
        if isOptimizationActive {
            applyOptimizations()
        }
    }
    
    func toggleOptimization() {
        if isOptimizationActive {
            deactivateOptimization()
        } else {
            activateOptimization()
        }
    }
    
    // MARK: - Performance Recommendations
    
    func getPerformanceRecommendations() -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        if currentMetrics.fps < lowFPSThreshold {
            recommendations.append(PerformanceRecommendation(
                type: .fps,
                message: "Low FPS detected. Consider reducing video quality or disabling some visualizations.",
                priority: .high
            ))
        }
        
        if currentMetrics.memoryUsage > highMemoryThreshold {
            recommendations.append(PerformanceRecommendation(
                type: .memory,
                message: "High memory usage detected. Consider closing unused panels or reducing cache size.",
                priority: .medium
            ))
        }
        
        if currentMetrics.cpuUsage > highCPUThreshold {
            recommendations.append(PerformanceRecommendation(
                type: .cpu,
                message: "High CPU usage detected. Consider reducing update frequency or enabling performance mode.",
                priority: .high
            ))
        }
        
        if currentMetrics.networkLatency > highLatencyThreshold {
            recommendations.append(PerformanceRecommendation(
                type: .network,
                message: "High network latency detected. Check network connection or reduce data transmission.",
                priority: .medium
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Performance Statistics
    
    func getPerformanceStatistics() -> PerformanceStatistics {
        return PerformanceStatistics(
            averageFPS: currentMetrics.fps,
            averageMemoryUsage: currentMetrics.memoryUsage,
            averageCPUUsage: currentMetrics.cpuUsage,
            averageLatency: currentMetrics.networkLatency,
            performanceScore: currentMetrics.performanceScore,
            optimizationActive: isOptimizationActive,
            optimizationLevel: optimizationLevel
        )
    }
}

// MARK: - Frame Time Tracker

class FrameTimeTracker {
    var onFrameTimeUpdate: ((Double) -> Void)?
    
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount = 0
    private var frameTimes: [CFTimeInterval] = []
    
    func updateFrameTime(_ frameTime: CFTimeInterval) {
        frameCount += 1
        frameTimes.append(frameTime)
        
        // Keep only last 60 frames
        if frameTimes.count > 60 {
            frameTimes.removeFirst()
        }
        
        // Calculate average frame time
        let averageFrameTime = frameTimes.reduce(0, +) / Double(frameTimes.count)
        onFrameTimeUpdate?(averageFrameTime)
        
        lastFrameTime = frameTime
    }
}

// MARK: - Performance Recommendation

struct PerformanceRecommendation {
    enum RecommendationType {
        case fps
        case memory
        case cpu
        case network
        case general
    }
    
    enum Priority {
        case low
        case medium
        case high
        case critical
    }
    
    let type: RecommendationType
    let message: String
    let priority: Priority
    let timestamp: Date = Date()
}

// MARK: - Performance Statistics

struct PerformanceStatistics {
    let averageFPS: Double
    let averageMemoryUsage: Double
    let averageCPUUsage: Double
    let averageLatency: Double
    let performanceScore: Double
    let optimizationActive: Bool
    let optimizationLevel: PerformanceManager.OptimizationLevel
    
    var performanceGrade: String {
        switch performanceScore {
        case 90...100: return "A+"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        case 50..<60: return "D"
        default: return "F"
        }
    }
    
    var performanceColor: Color {
        switch performanceScore {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

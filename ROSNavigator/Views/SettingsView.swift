//
//  SettingsView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) var appModel
    @StateObject private var errorManager = ErrorHandlingManager()
    @StateObject private var performanceManager = PerformanceManager()
    @StateObject private var userExperienceManager = UserExperienceManager()
    
    @State private var selectedTab: SettingsTab = .general
    @State private var showingTutorial = false
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case performance = "Performance"
        case accessibility = "Accessibility"
        case errors = "Errors"
        case about = "About"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .performance: return "speedometer"
            case .accessibility: return "accessibility"
            case .errors: return "exclamationmark.triangle"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Settings Tab", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        HStack {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                ScrollView {
                    Group {
                        switch selectedTab {
                        case .general:
                            GeneralSettingsView(
                                appModel: appModel,
                                userExperienceManager: userExperienceManager,
                                showingTutorial: $showingTutorial
                            )
                        case .performance:
                            PerformanceSettingsView(performanceManager: performanceManager)
                        case .accessibility:
                            AccessibilitySettingsView(userExperienceManager: userExperienceManager)
                        case .errors:
                            ErrorSettingsView(errorManager: errorManager)
                        case .about:
                            AboutSettingsView()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingTutorial) {
            TutorialView(userExperienceManager: userExperienceManager)
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Environment(AppModel.self) var appModel
    let userExperienceManager: UserExperienceManager
    @Binding var showingTutorial: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Robot Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Robot Selection")
                    .font(.headline)
                
                Picker("Selected Robot", selection: $appModel.selectedRobot) {
                    ForEach(AppModel.Robot.allCases) { robot in
                        Text(robot.displayName).tag(robot)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Connection Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection Settings")
                    .font(.headline)
                
                HStack {
                    Text("Robot IP:")
                    TextField("192.168.1.49", text: .constant("192.168.1.49"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 150)
                }
                
                HStack {
                    Text("WebSocket Port:")
                    TextField("9090", text: .constant("9090"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 100)
                }
                
                HStack {
                    Text("Video Port:")
                    TextField("8080", text: .constant("8080"))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 100)
                }
            }
            
            // Tutorial
            VStack(alignment: .leading, spacing: 8) {
                Text("Tutorial")
                    .font(.headline)
                
                Button("Start Tutorial") {
                    showingTutorial = true
                }
                .buttonStyle(.borderedProminent)
                
                if userExperienceManager.isFirstLaunch {
                    Text("First time using the app? Start with the tutorial to learn the basics.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Feedback
            VStack(alignment: .leading, spacing: 8) {
                Text("Feedback")
                    .font(.headline)
                
                Toggle("Haptic Feedback", isOn: $userExperienceManager.hapticFeedbackEnabled)
                Toggle("Audio Cues", isOn: $userExperienceManager.audioCuesEnabled)
            }
        }
    }
}

// MARK: - Performance Settings

struct PerformanceSettingsView: View {
    @ObservedObject var performanceManager: PerformanceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Current Performance
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Performance")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("FPS: \(String(format: "%.1f", performanceManager.currentMetrics.fps))")
                        Text("Memory: \(String(format: "%.1f", performanceManager.currentMetrics.memoryUsage)) MB")
                        Text("CPU: \(String(format: "%.1f", performanceManager.currentMetrics.cpuUsage))%")
                    }
                    .font(.caption)
                    .fontDesign(.monospaced)
                    
                    Spacer()
                    
                    VStack {
                        Text("Score")
                            .font(.caption)
                        Text("\(Int(performanceManager.currentMetrics.performanceScore))")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(performanceManager.currentMetrics.performanceScore > 80 ? .green : .orange)
                    }
                }
            }
            
            // Optimization Level
            VStack(alignment: .leading, spacing: 8) {
                Text("Optimization Level")
                    .font(.headline)
                
                Picker("Optimization Level", selection: $performanceManager.optimizationLevel) {
                    Text("Performance").tag(PerformanceManager.OptimizationLevel.performance)
                    Text("Balanced").tag(PerformanceManager.OptimizationLevel.balanced)
                    Text("Quality").tag(PerformanceManager.OptimizationLevel.quality)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Auto Optimization
            VStack(alignment: .leading, spacing: 8) {
                Text("Auto Optimization")
                    .font(.headline)
                
                Toggle("Enable Auto Optimization", isOn: $performanceManager.isOptimizationActive)
                
                if performanceManager.isOptimizationActive {
                    Text("Automatically optimizes performance when issues are detected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Performance Recommendations
            let recommendations = performanceManager.getPerformanceRecommendations()
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations")
                        .font(.headline)
                    
                    ForEach(recommendations, id: \.message) { recommendation in
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                            Text(recommendation.message)
                                .font(.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

// MARK: - Accessibility Settings

struct AccessibilitySettingsView: View {
    @ObservedObject var userExperienceManager: UserExperienceManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Visual Accessibility
            VStack(alignment: .leading, spacing: 8) {
                Text("Visual Accessibility")
                    .font(.headline)
                
                Toggle("High Contrast Mode", isOn: $userExperienceManager.accessibilitySettings.highContrastMode)
                Toggle("Large Text Size", isOn: $userExperienceManager.accessibilitySettings.largeTextSize)
                Toggle("Color Blind Support", isOn: $userExperienceManager.accessibilitySettings.colorBlindSupport)
            }
            
            // Motion & Interaction
            VStack(alignment: .leading, spacing: 8) {
                Text("Motion & Interaction")
                    .font(.headline)
                
                Toggle("Reduce Motion", isOn: $userExperienceManager.accessibilitySettings.reducedMotion)
                Toggle("Haptic Feedback", isOn: $userExperienceManager.accessibilitySettings.hapticFeedbackEnabled)
                Toggle("Audio Cues", isOn: $userExperienceManager.accessibilitySettings.audioCuesEnabled)
            }
            
            // Screen Reader
            VStack(alignment: .leading, spacing: 8) {
                Text("Screen Reader")
                    .font(.headline)
                
                Toggle("VoiceOver Support", isOn: $userExperienceManager.accessibilitySettings.voiceOverEnabled)
                Toggle("Screen Reader Support", isOn: $userExperienceManager.accessibilitySettings.screenReaderSupport)
            }
            
            // Accessibility Status
            VStack(alignment: .leading, spacing: 8) {
                Text("System Status")
                    .font(.headline)
                
                HStack {
                    Image(systemName: userExperienceManager.voiceOverEnabled ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(userExperienceManager.voiceOverEnabled ? .green : .red)
                    Text("VoiceOver: \(userExperienceManager.voiceOverEnabled ? "Enabled" : "Disabled")")
                }
                
                HStack {
                    Image(systemName: UIAccessibility.isReduceMotionEnabled ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(UIAccessibility.isReduceMotionEnabled ? .green : .red)
                    Text("Reduce Motion: \(UIAccessibility.isReduceMotionEnabled ? "Enabled" : "Disabled")")
                }
            }
            .font(.caption)
        }
    }
}

// MARK: - Error Settings

struct ErrorSettingsView: View {
    @ObservedObject var errorManager: ErrorHandlingManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Error Statistics
            let stats = errorManager.getErrorStatistics()
            VStack(alignment: .leading, spacing: 8) {
                Text("Error Statistics")
                    .font(.headline)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Errors: \(stats.totalErrors)")
                        Text("Resolved: \(stats.resolvedErrors)")
                        Text("Critical: \(stats.criticalErrors)")
                    }
                    .font(.caption)
                    .fontDesign(.monospaced)
                    
                    Spacer()
                    
                    VStack {
                        Text("Resolution Rate")
                            .font(.caption)
                        Text("\(Int(stats.resolutionRate * 100))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(stats.resolutionRate > 0.8 ? .green : .orange)
                    }
                }
            }
            
            // Error Management
            VStack(alignment: .leading, spacing: 8) {
                Text("Error Management")
                    .font(.headline)
                
                Button("Clear Resolved Errors") {
                    errorManager.clearResolvedErrors()
                }
                .buttonStyle(.bordered)
                
                Button("Clear All Errors") {
                    errorManager.clearAllErrors()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            
            // Recent Errors
            if !errorManager.errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Errors")
                        .font(.headline)
                    
                    ForEach(errorManager.errors.suffix(5)) { error in
                        HStack {
                            Circle()
                                .fill(error.severity.color)
                                .frame(width: 8, height: 8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(error.message)
                                    .font(.caption)
                                    .lineLimit(1)
                                
                                Text(error.category.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if error.isResolved {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // App Information
            VStack(alignment: .leading, spacing: 8) {
                Text("App Information")
                    .font(.headline)
                
                HStack {
                    Text("Version:")
                    Spacer()
                    Text("1.0.0")
                        .fontDesign(.monospaced)
                }
                
                HStack {
                    Text("Build:")
                    Spacer()
                    Text("2025.10.21")
                        .fontDesign(.monospaced)
                }
                
                HStack {
                    Text("Platform:")
                    Spacer()
                    Text("visionOS")
                        .fontDesign(.monospaced)
                }
            }
            
            // System Information
            VStack(alignment: .leading, spacing: 8) {
                Text("System Information")
                    .font(.headline)
                
                HStack {
                    Text("Device:")
                    Spacer()
                    Text("Apple Vision Pro")
                        .fontDesign(.monospaced)
                }
                
                HStack {
                    Text("OS Version:")
                    Spacer()
                    Text("visionOS 1.0+")
                        .fontDesign(.monospaced)
                }
            }
            
            // Credits
            VStack(alignment: .leading, spacing: 8) {
                Text("Credits")
                    .font(.headline)
                
                Text("ROSNavigator - VisionOS Teleoperation Interface")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Built with SwiftUI, RealityKit, and ROS2")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Tutorial View

struct TutorialView: View {
    @ObservedObject var userExperienceManager: UserExperienceManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let currentStep = userExperienceManager.currentTutorial {
                    // Tutorial Step Content
                    VStack(spacing: 16) {
                        Image(systemName: currentStep.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text(currentStep.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(currentStep.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    
                    // Progress Indicator
                    ProgressView(value: Double(TutorialStep.allCases.firstIndex(of: currentStep) ?? 0) + 1, 
                                total: Double(TutorialStep.allCases.count))
                        .padding(.horizontal)
                    
                    // Navigation Buttons
                    HStack(spacing: 20) {
                        Button("Previous") {
                            userExperienceManager.previousTutorialStep()
                        }
                        .disabled(currentStep == .welcome)
                        
                        Spacer()
                        
                        if currentStep == .completed {
                            Button("Done") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Next") {
                                userExperienceManager.nextTutorialStep()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Tutorial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        userExperienceManager.skipTutorial()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppModel())
}

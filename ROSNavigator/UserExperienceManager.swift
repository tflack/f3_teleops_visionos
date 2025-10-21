//
//  UserExperienceManager.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class UserExperienceManager: ObservableObject {
    @Published var isFirstLaunch = true
    @Published var currentTutorial: TutorialStep?
    @Published var isTutorialActive = false
    @Published var accessibilitySettings = AccessibilitySettings()
    @Published var hapticFeedbackEnabled = true
    @Published var audioCuesEnabled = true
    @Published var voiceOverEnabled = false
    
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    
    // Tutorial steps
    enum TutorialStep: String, CaseIterable {
        case welcome = "welcome"
        case handGestures = "hand_gestures"
        case gamepadControls = "gamepad_controls"
        case cameraView = "camera_view"
        case robotControl = "robot_control"
        case emergencyStop = "emergency_stop"
        case panelManagement = "panel_management"
        case completed = "completed"
        
        var title: String {
            switch self {
            case .welcome: return "Welcome to ROSNavigator"
            case .handGestures: return "Hand Gesture Controls"
            case .gamepadControls: return "Gamepad Controls"
            case .cameraView: return "Camera View"
            case .robotControl: return "Robot Control"
            case .emergencyStop: return "Emergency Stop"
            case .panelManagement: return "Panel Management"
            case .completed: return "Tutorial Complete"
            }
        }
        
        var description: String {
            switch self {
            case .welcome:
                return "Welcome to ROSNavigator! This tutorial will guide you through the basic controls and features."
            case .handGestures:
                return "Use hand gestures to control the virtual joysticks. Drag your finger to move the robot."
            case .gamepadControls:
                return "Connect a Bluetooth gamepad for precise control. Use the left stick for movement and right stick for rotation."
            case .cameraView:
                return "The center panel shows the robot's camera feed. You can see what the robot sees in real-time."
            case .robotControl:
                return "Use the control panel to adjust speed, switch between manual and arm modes, and control the robot."
            case .emergencyStop:
                return "The red emergency stop button will immediately halt all robot movement. Use it in case of emergency."
            case .panelManagement:
                return "You can move, resize, and organize panels in 3D space. Use gestures to interact with them."
            case .completed:
                return "You're all set! You can restart this tutorial anytime from the settings."
            }
        }
        
        var icon: String {
            switch self {
            case .welcome: return "hand.wave"
            case .handGestures: return "hand.point.up"
            case .gamepadControls: return "gamecontroller"
            case .cameraView: return "camera"
            case .robotControl: return "gear"
            case .emergencyStop: return "exclamationmark.triangle"
            case .panelManagement: return "rectangle.3.group"
            case .completed: return "checkmark.circle"
            }
        }
        
        var duration: TimeInterval {
            switch self {
            case .welcome: return 3.0
            case .handGestures: return 5.0
            case .gamepadControls: return 4.0
            case .cameraView: return 3.0
            case .robotControl: return 4.0
            case .emergencyStop: return 3.0
            case .panelManagement: return 4.0
            case .completed: return 2.0
            }
        }
    }
    
    // Accessibility settings
    struct AccessibilitySettings {
        var highContrastMode = false
        var largeTextSize = false
        var reducedMotion = false
        var voiceOverEnabled = false
        var hapticFeedbackEnabled = true
        var audioCuesEnabled = true
        var colorBlindSupport = false
        var screenReaderSupport = false
    }
    
    init() {
        loadUserPreferences()
        setupAccessibilityMonitoring()
    }
    
    // MARK: - Tutorial Management
    
    func startTutorial() {
        isTutorialActive = true
        currentTutorial = .welcome
        showTutorialStep(.welcome)
    }
    
    func nextTutorialStep() {
        guard let current = currentTutorial else { return }
        
        let allSteps = TutorialStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: current) else { return }
        
        let nextIndex = currentIndex + 1
        if nextIndex < allSteps.count {
            let nextStep = allSteps[nextIndex]
            currentTutorial = nextStep
            showTutorialStep(nextStep)
        } else {
            completeTutorial()
        }
    }
    
    func previousTutorialStep() {
        guard let current = currentTutorial else { return }
        
        let allSteps = TutorialStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: current) else { return }
        
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            let previousStep = allSteps[previousIndex]
            currentTutorial = previousStep
            showTutorialStep(previousStep)
        }
    }
    
    func skipTutorial() {
        isTutorialActive = false
        currentTutorial = nil
        isFirstLaunch = false
        saveUserPreferences()
    }
    
    func completeTutorial() {
        isTutorialActive = false
        currentTutorial = .completed
        isFirstLaunch = false
        saveUserPreferences()
        
        // Provide completion feedback
        provideHapticFeedback(.success)
        provideAudioCue(.success)
    }
    
    private func showTutorialStep(_ step: TutorialStep) {
        // Show tutorial step with appropriate UI
        print("📚 Tutorial Step: \(step.title)")
        
        // Provide haptic feedback
        provideHapticFeedback(.light)
        
        // Provide audio cue
        provideAudioCue(.information)
        
        // Auto-advance after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + step.duration) {
            if self.currentTutorial == step {
                self.nextTutorialStep()
            }
        }
    }
    
    // MARK: - Haptic Feedback
    
    func provideHapticFeedback(_ type: HapticFeedbackType) {
        guard hapticFeedbackEnabled && accessibilitySettings.hapticFeedbackEnabled else { return }
        
        // Note: UIKit haptic feedback is not available in visionOS
        // This is a placeholder for future visionOS-specific haptic feedback implementation
        switch type {
        case .light, .medium, .heavy:
            // Placeholder for impact feedback
            print("🔊 Haptic feedback: \(type)")
        case .success, .warning, .error:
            // Placeholder for notification feedback
            print("🔊 Haptic feedback: \(type)")
        case .selection:
            // Placeholder for selection feedback
            print("🔊 Haptic feedback: \(type)")
        }
    }
    
    enum HapticFeedbackType {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
        case selection
    }
    
    // MARK: - Audio Cues
    
    func provideAudioCue(_ type: AudioCueType) {
        guard audioCuesEnabled && accessibilitySettings.audioCuesEnabled else { return }
        
        // In a real implementation, this would play appropriate audio cues
        switch type {
        case .information:
            print("🔊 Audio cue: Information")
        case .success:
            print("🔊 Audio cue: Success")
        case .warning:
            print("🔊 Audio cue: Warning")
        case .error:
            print("🔊 Audio cue: Error")
        case .buttonPress:
            print("🔊 Audio cue: Button press")
        case .panelOpen:
            print("🔊 Audio cue: Panel open")
        case .panelClose:
            print("🔊 Audio cue: Panel close")
        }
    }
    
    enum AudioCueType {
        case information
        case success
        case warning
        case error
        case buttonPress
        case panelOpen
        case panelClose
    }
    
    // MARK: - Accessibility Support
    
    private func setupAccessibilityMonitoring() {
        // Monitor for accessibility changes
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateVoiceOverStatus()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateReduceMotionStatus()
            }
            .store(in: &cancellables)
    }
    
    private func updateVoiceOverStatus() {
        voiceOverEnabled = UIAccessibility.isVoiceOverRunning
        accessibilitySettings.voiceOverEnabled = voiceOverEnabled
        
        if voiceOverEnabled {
            // Provide voice over specific feedback
            provideAudioCue(.information)
        }
    }
    
    private func updateReduceMotionStatus() {
        accessibilitySettings.reducedMotion = UIAccessibility.isReduceMotionEnabled
        
        if accessibilitySettings.reducedMotion {
            // Disable animations and transitions
            print("♿ Reduced motion enabled")
        }
    }
    
    // MARK: - User Preferences
    
    private func loadUserPreferences() {
        isFirstLaunch = userDefaults.bool(forKey: "isFirstLaunch")
        hapticFeedbackEnabled = userDefaults.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true
        audioCuesEnabled = userDefaults.object(forKey: "audioCuesEnabled") as? Bool ?? true
        
        // Load accessibility settings
        if let data = userDefaults.data(forKey: "accessibilitySettings"),
           let settings = try? JSONDecoder().decode(AccessibilitySettings.self, from: data) {
            accessibilitySettings = settings
        }
    }
    
    private func saveUserPreferences() {
        userDefaults.set(isFirstLaunch, forKey: "isFirstLaunch")
        userDefaults.set(hapticFeedbackEnabled, forKey: "hapticFeedbackEnabled")
        userDefaults.set(audioCuesEnabled, forKey: "audioCuesEnabled")
        
        // Save accessibility settings
        if let data = try? JSONEncoder().encode(accessibilitySettings) {
            userDefaults.set(data, forKey: "accessibilitySettings")
        }
    }
    
    // MARK: - Accessibility Controls
    
    func toggleHapticFeedback() {
        hapticFeedbackEnabled.toggle()
        accessibilitySettings.hapticFeedbackEnabled = hapticFeedbackEnabled
        saveUserPreferences()
        
        if hapticFeedbackEnabled {
            provideHapticFeedback(.success)
        }
    }
    
    func toggleAudioCues() {
        audioCuesEnabled.toggle()
        accessibilitySettings.audioCuesEnabled = audioCuesEnabled
        saveUserPreferences()
        
        if audioCuesEnabled {
            provideAudioCue(.success)
        }
    }
    
    func toggleHighContrast() {
        accessibilitySettings.highContrastMode.toggle()
        saveUserPreferences()
    }
    
    func toggleLargeText() {
        accessibilitySettings.largeTextSize.toggle()
        saveUserPreferences()
    }
    
    func toggleColorBlindSupport() {
        accessibilitySettings.colorBlindSupport.toggle()
        saveUserPreferences()
    }
    
    // MARK: - User Experience Analytics
    
    func trackUserInteraction(_ interaction: UserInteraction) {
        // Track user interactions for analytics and improvement
        print("📊 User interaction: \(interaction.type) - \(interaction.details)")
    }
    
    struct UserInteraction {
        let type: InteractionType
        let details: String
        let timestamp: Date = Date()
        
        enum InteractionType {
            case buttonPress
            case gesture
            case gamepadInput
            case panelInteraction
            case tutorialStep
            case error
            case performance
        }
    }
}

// MARK: - Accessibility Settings Extensions

extension UserExperienceManager.AccessibilitySettings: Codable {
    enum CodingKeys: String, CodingKey {
        case highContrastMode
        case largeTextSize
        case reducedMotion
        case voiceOverEnabled
        case hapticFeedbackEnabled
        case audioCuesEnabled
        case colorBlindSupport
        case screenReaderSupport
    }
}

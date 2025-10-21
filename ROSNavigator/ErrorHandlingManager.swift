//
//  ErrorHandlingManager.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ErrorHandlingManager: ObservableObject {
    @Published var errors: [AppError] = []
    @Published var warnings: [AppWarning] = []
    @Published var isRecoveryInProgress = false
    @Published var lastError: AppError?
    
    private var cancellables = Set<AnyCancellable>()
    private var recoveryTimer: Timer?
    
    // Error categories
    enum ErrorCategory {
        case network
        case ros2
        case camera
        case gamepad
        case performance
        case system
    }
    
    // Error severity levels
    enum ErrorSeverity {
        case low
        case medium
        case high
        case critical
    }
    
    struct AppError: Identifiable, Equatable {
        let id = UUID()
        let timestamp: Date
        let category: ErrorCategory
        let severity: ErrorSeverity
        let message: String
        let details: String?
        let recoveryAction: RecoveryAction?
        var isResolved: Bool = false
        
        static func == (lhs: AppError, rhs: AppError) -> Bool {
            return lhs.id == rhs.id
        }
    }
    
    struct AppWarning: Identifiable {
        let id = UUID()
        let timestamp: Date
        let category: ErrorCategory
        let message: String
        let details: String?
        var isDismissed: Bool = false
    }
    
    enum RecoveryAction {
        case reconnect
        case restart
        case fallback
        case userAction
        case automatic
    }
    
    init() {
        setupErrorMonitoring()
    }
    
    // MARK: - Error Reporting
    
    func reportError(
        category: ErrorCategory,
        severity: ErrorSeverity,
        message: String,
        details: String? = nil,
        recoveryAction: RecoveryAction? = nil
    ) {
        let error = AppError(
            timestamp: Date(),
            category: category,
            severity: severity,
            message: message,
            details: details,
            recoveryAction: recoveryAction
        )
        
        errors.append(error)
        lastError = error
        
        // Auto-recovery for certain errors
        if let recoveryAction = recoveryAction, recoveryAction == .automatic {
            attemptRecovery(for: error)
        }
        
        // Log error
        logError(error)
    }
    
    func reportWarning(
        category: ErrorCategory,
        message: String,
        details: String? = nil
    ) {
        let warning = AppWarning(
            timestamp: Date(),
            category: category,
            message: message,
            details: details
        )
        
        warnings.append(warning)
        logWarning(warning)
    }
    
    // MARK: - Error Recovery
    
    func attemptRecovery(for error: AppError) {
        guard !isRecoveryInProgress else { return }
        
        isRecoveryInProgress = true
        
        Task {
            do {
                try await performRecovery(for: error)
                markErrorAsResolved(error)
            } catch {
                reportError(
                    category: .system,
                    severity: .medium,
                    message: "Recovery failed for \(error.localizedDescription)",
                    details: error.localizedDescription
                )
            }
            
            isRecoveryInProgress = false
        }
    }
    
    private func performRecovery(for error: AppError) async throws {
        guard let recoveryAction = error.recoveryAction else {
            throw NSError(domain: "ErrorHandling", code: -1, userInfo: [NSLocalizedDescriptionKey: "No recovery action available"])
        }
        
        switch recoveryAction {
        case .reconnect:
            try await performReconnection(for: error)
        case .restart:
            try await performRestart(for: error)
        case .fallback:
            try await performFallback(for: error)
        case .userAction:
            // User action required - don't auto-recover
            break
        case .automatic:
            // Already handled
            break
        }
    }
    
    private func performReconnection(for error: AppError) async throws {
        switch error.category {
        case .network, .ros2:
            // Attempt to reconnect to ROS2
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            // Trigger reconnection in ROS2WebSocketManager
        case .camera:
            // Attempt to reconnect camera streams
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            // Trigger camera stream reconnection
        default:
            break
        }
    }
    
    private func performRestart(for error: AppError) async throws {
        switch error.category {
        case .gamepad:
            // Restart gamepad connection
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            // Trigger gamepad restart
        case .system:
            // Restart system components
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        default:
            break
        }
    }
    
    private func performFallback(for error: AppError) async throws {
        switch error.category {
        case .camera:
            // Switch to alternative camera feed
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        case .ros2:
            // Switch to native ROS2 bridge
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        default:
            break
        }
    }
    
    // MARK: - Error Management
    
    func markErrorAsResolved(_ error: AppError) {
        if let index = errors.firstIndex(of: error) {
            errors[index].isResolved = true
        }
    }
    
    func dismissWarning(_ warning: AppWarning) {
        if let index = warnings.firstIndex(where: { $0.id == warning.id }) {
            warnings[index].isDismissed = true
        }
    }
    
    func clearResolvedErrors() {
        errors.removeAll { $0.isResolved }
    }
    
    func clearDismissedWarnings() {
        warnings.removeAll { $0.isDismissed }
    }
    
    func clearAllErrors() {
        errors.removeAll()
        warnings.removeAll()
        lastError = nil
    }
    
    // MARK: - Error Monitoring
    
    private func setupErrorMonitoring() {
        // Monitor for critical errors that require immediate attention
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkForCriticalErrors()
            }
            .store(in: &cancellables)
    }
    
    private func checkForCriticalErrors() {
        let criticalErrors = errors.filter { 
            $0.severity == .critical && !$0.isResolved 
        }
        
        if !criticalErrors.isEmpty {
            // Handle critical errors
            for error in criticalErrors {
                handleCriticalError(error)
            }
        }
    }
    
    private func handleCriticalError(_ error: AppError) {
        // Critical errors require immediate user attention
        // This could trigger emergency stop, show critical alert, etc.
        print("🚨 CRITICAL ERROR: \(error.message)")
    }
    
    // MARK: - Logging
    
    private func logError(_ error: AppError) {
        let logMessage = """
        [ERROR] \(error.timestamp) - \(error.category) - \(error.severity)
        Message: \(error.message)
        Details: \(error.details ?? "None")
        Recovery: \(error.recoveryAction?.description ?? "None")
        """
        print(logMessage)
    }
    
    private func logWarning(_ warning: AppWarning) {
        let logMessage = """
        [WARNING] \(warning.timestamp) - \(warning.category)
        Message: \(warning.message)
        Details: \(warning.details ?? "None")
        """
        print(logMessage)
    }
    
    // MARK: - Error Statistics
    
    func getErrorStatistics() -> ErrorStatistics {
        let totalErrors = errors.count
        let resolvedErrors = errors.filter { $0.isResolved }.count
        let criticalErrors = errors.filter { $0.severity == .critical && !$0.isResolved }.count
        
        let errorsByCategory = Dictionary(grouping: errors, by: { $0.category })
        let errorsBySeverity = Dictionary(grouping: errors, by: { $0.severity })
        
        return ErrorStatistics(
            totalErrors: totalErrors,
            resolvedErrors: resolvedErrors,
            criticalErrors: criticalErrors,
            errorsByCategory: errorsByCategory,
            errorsBySeverity: errorsBySeverity,
            lastErrorTime: errors.last?.timestamp
        )
    }
}

// MARK: - Error Statistics

struct ErrorStatistics {
    let totalErrors: Int
    let resolvedErrors: Int
    let criticalErrors: Int
    let errorsByCategory: [ErrorHandlingManager.ErrorCategory: [ErrorHandlingManager.AppError]]
    let errorsBySeverity: [ErrorHandlingManager.ErrorSeverity: [ErrorHandlingManager.AppError]]
    let lastErrorTime: Date?
    
    var resolutionRate: Double {
        guard totalErrors > 0 else { return 1.0 }
        return Double(resolvedErrors) / Double(totalErrors)
    }
    
    var hasActiveCriticalErrors: Bool {
        return criticalErrors > 0
    }
}

// MARK: - Error Extensions

extension ErrorHandlingManager.ErrorCategory {
    var displayName: String {
        switch self {
        case .network: return "Network"
        case .ros2: return "ROS2"
        case .camera: return "Camera"
        case .gamepad: return "Gamepad"
        case .performance: return "Performance"
        case .system: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .network: return "network"
        case .ros2: return "gear"
        case .camera: return "camera"
        case .gamepad: return "gamecontroller"
        case .performance: return "speedometer"
        case .system: return "exclamationmark.triangle"
        }
    }
}

extension ErrorHandlingManager.ErrorSeverity {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

extension ErrorHandlingManager.RecoveryAction {
    var description: String {
        switch self {
        case .reconnect: return "Reconnect"
        case .restart: return "Restart"
        case .fallback: return "Fallback"
        case .userAction: return "User Action Required"
        case .automatic: return "Automatic"
        }
    }
}

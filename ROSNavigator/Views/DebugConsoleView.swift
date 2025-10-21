//
//  DebugConsoleView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import Combine

struct DebugConsoleView: View {
    @Environment(AppModel.self) var appModel
    let ros2Manager: ROS2WebSocketManager
    let gamepadManager: GamepadManager
    
    @State private var isExpanded = false
    @State private var selectedTab: DebugTab = .messages
    @State private var messageFilter = ""
    @State private var showOnlyErrors = false
    @State private var performanceMetrics = PerformanceManager.PerformanceMetrics()
    @State private var cancellables = Set<AnyCancellable>()
    
    enum DebugTab: String, CaseIterable {
        case messages = "Messages"
        case performance = "Performance"
        case connections = "Connections"
        case gamepad = "Gamepad"
        
        var icon: String {
            switch self {
            case .messages: return "message"
            case .performance: return "speedometer"
            case .connections: return "network"
            case .gamepad: return "gamecontroller"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.blue)
                Text("Debug Console")
                    .font(.headline)
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            if isExpanded {
                // Tab Selector
                Picker("Debug Tab", selection: $selectedTab) {
                    ForEach(DebugTab.allCases, id: \.self) { tab in
                        HStack {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Content
                Group {
                    switch selectedTab {
                    case .messages:
                        MessagesView(
                            ros2Manager: ros2Manager,
                            filter: $messageFilter,
                            showOnlyErrors: $showOnlyErrors
                        )
                    case .performance:
                        PerformanceView(metrics: $performanceMetrics)
                    case .connections:
                        ConnectionsView(ros2Manager: ros2Manager)
                    case .gamepad:
                        GamepadDebugView(gamepadManager: gamepadManager)
                    }
                }
                .frame(maxHeight: 300)
                .background(Color.black.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            startPerformanceMonitoring()
        }
    }
    
    private func startPerformanceMonitoring() {
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                updatePerformanceMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func updatePerformanceMetrics() {
        // Update performance metrics
        performanceMetrics.fps = calculateFPS()
        performanceMetrics.memoryUsage = getMemoryUsage()
        performanceMetrics.networkLatency = calculateNetworkLatency()
    }
    
    private func calculateFPS() -> Double {
        // Calculate FPS based on frame timing
        return 60.0 // Placeholder
    }
    
    private func getMemoryUsage() -> Double {
        // Get current memory usage
        return 0.0 // Placeholder
    }
    
    private func calculateNetworkLatency() -> Double {
        // Calculate network latency to robot
        return 0.0 // Placeholder
    }
}

// MARK: - Messages View

public struct MessagesView: View {
    let ros2Manager: ROS2WebSocketManager
    @Binding var filter: String
    @Binding var showOnlyErrors: Bool
    
    @State private var messages: [DebugMessage] = []
    @State private var cancellables = Set<AnyCancellable>()
    
    public init(ros2Manager: ROS2WebSocketManager, filter: Binding<String>, showOnlyErrors: Binding<Bool>) {
        self.ros2Manager = ros2Manager
        self._filter = filter
        self._showOnlyErrors = showOnlyErrors
    }
    
    var filteredMessages: [DebugMessage] {
        var filtered = messages
        
        if !filter.isEmpty {
            filtered = filtered.filter { message in
                message.content.localizedCaseInsensitiveContains(filter)
            }
        }
        
        if showOnlyErrors {
            filtered = filtered.filter { $0.level == .error }
        }
        
        return filtered.suffix(100) // Keep last 100 messages
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Filter Controls
            HStack {
                TextField("Filter messages...", text: $filter)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
                
                Toggle("Errors Only", isOn: $showOnlyErrors)
                    .toggleStyle(SwitchToggleStyle())
                
                Spacer()
                
                Button("Clear") {
                    messages.removeAll()
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal)
            
            // Messages List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(filteredMessages, id: \.id) { message in
                        MessageRowView(message: message)
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            startMessageCollection()
        }
    }
    
    private func startMessageCollection() {
        // Collect messages from ROS2 manager
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Add new messages from ROS2 manager
                // This would be connected to the actual message logging
            }
            .store(in: &cancellables)
    }
    
}

struct MessageRowView: View {
    let message: DebugMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Level indicator
            Circle()
                .fill(levelColor)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.topic)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var levelColor: Color {
        switch message.level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .debug: return .gray
        }
    }
}

// MARK: - Performance View

struct PerformanceView: View {
    @Binding var metrics: PerformanceManager.PerformanceMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(
                    title: "FPS",
                    value: String(format: "%.1f", metrics.fps),
                    unit: "fps",
                    color: metrics.fps > 30 ? .green : .orange
                )
                
                MetricCard(
                    title: "Memory",
                    value: String(format: "%.1f", metrics.memoryUsage),
                    unit: "MB",
                    color: metrics.memoryUsage < 100 ? .green : .orange
                )
                
                MetricCard(
                    title: "Latency",
                    value: String(format: "%.0f", metrics.networkLatency),
                    unit: "ms",
                    color: metrics.networkLatency < 50 ? .green : .red
                )
                
                MetricCard(
                    title: "CPU",
                    value: String(format: "%.1f", metrics.cpuUsage),
                    unit: "%",
                    color: metrics.cpuUsage < 50 ? .green : .orange
                )
            }
            .padding(.horizontal)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Connections View

struct ConnectionsView: View {
    let ros2Manager: ROS2WebSocketManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Status")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                ConnectionRow(
                    name: "ROS2 WebSocket",
                    status: ros2Manager.connectionState,
                    endpoint: "ws://192.168.1.49:9090"
                )
                
                ConnectionRow(
                    name: "Video Streams",
                    status: .connected,
                    endpoint: "http://192.168.1.49:8080"
                )
                
                ConnectionRow(
                    name: "Robot Controller",
                    status: .connected,
                    endpoint: "192.168.1.49:9090"
                )
            }
            .padding(.horizontal)
        }
    }
}

struct ConnectionRow: View {
    let name: String
    let status: ROS2WebSocketManager.ConnectionState
    let endpoint: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(endpoint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Gamepad Debug View

struct GamepadDebugView: View {
    let gamepadManager: GamepadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gamepad Status")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(gamepadManager.isConnected ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text("Gamepad Connected: \(gamepadManager.isConnected ? "Yes" : "No")")
                        .font(.subheadline)
                }
                
                if gamepadManager.isConnected {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Left Stick: (\(String(format: "%.2f", gamepadManager.leftStick.x)), \(String(format: "%.2f", gamepadManager.leftStick.y)))")
                            .font(.caption)
                            .fontDesign(.monospaced)
                        
                        Text("Right Stick: (\(String(format: "%.2f", gamepadManager.rightStick.x)), \(String(format: "%.2f", gamepadManager.rightStick.y)))")
                            .font(.caption)
                            .fontDesign(.monospaced)
                        
                        Text("Left Trigger: \(String(format: "%.2f", gamepadManager.leftTrigger))")
                            .font(.caption)
                            .fontDesign(.monospaced)
                        
                        Text("Right Trigger: \(String(format: "%.2f", gamepadManager.rightTrigger))")
                            .font(.caption)
                            .fontDesign(.monospaced)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Types

struct DebugMessage: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: MessageLevel
    let topic: String
    let content: String
    
    enum MessageLevel {
        case info, warning, error, debug
    }
}

// PerformanceMetrics is defined in PerformanceManager.swift

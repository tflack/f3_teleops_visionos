//
//  SpatialTeleopView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import Combine

struct SpatialTeleopView: View {
    @Environment(AppModel.self) var appModel
    @State private var ros2Manager: ROS2WebSocketManager
    @State private var gamepadManager = GamepadManager()
    @State private var inputCoordinator: InputCoordinator?
    @State private var robotControlManager: RobotControlManager?
    @State private var actionManager: ActionManager?
    @State private var windowCoordinator = WindowCoordinator()
    @State private var nativeROS2Bridge: ROS2NativeBridge?
    @State private var cancellables = Set<AnyCancellable>()
    
    let onExit: (() -> Void)?
    
    init(onExit: (() -> Void)? = nil) {
        self.onExit = onExit
        print("🌐 SpatialTeleopView init called")
        // Use singleton instance and update IP if needed
        _ros2Manager = State(initialValue: ROS2WebSocketManager.shared)
        ros2Manager.updateServerIP(AppModel.Robot.alpha.ipAddress)
    }
    
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Teleoperation Control")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Connection status
                HStack(spacing: 8) {
                    Circle()
                        .fill(ros2Manager.isConnected ? .green : .red)
                        .frame(width: 12, height: 12)
                    Text(ros2Manager.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Exit button
                Button(action: {
                    onExit?()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                        Text("Exit")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Camera feeds in a side-by-side layout
            HStack(spacing: 20) {
                // RGB Camera Feed
                VStack {
                    Text("RGB Camera")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    CameraFeedView(ros2Manager: ros2Manager, selectedCamera: .constant(.rgb))
                        .frame(width: 400, height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
                
                // Heatmap Camera Feed
                VStack {
                    Text("Heatmap Camera")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    CameraFeedView(ros2Manager: ros2Manager, selectedCamera: .constant(.heatmap))
                        .frame(width: 400, height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .onAppear {
            print("🌐 SpatialTeleopView onAppear called")
            setupROS2Connection()
            setupManagers()
        }
        .onDisappear {
            ros2Manager.disconnect()
            nativeROS2Bridge?.disconnect()
        }
    }
    
    private func setupManagers() {
        // Initialize input coordinator
        inputCoordinator = InputCoordinator(gamepadManager: gamepadManager)
        
        // Initialize robot control manager
        if let inputCoordinator = inputCoordinator {
            robotControlManager = RobotControlManager(ros2Manager: ros2Manager, inputCoordinator: inputCoordinator)
        }
        
        // Initialize action manager
        actionManager = ActionManager(ros2Manager: ros2Manager)
        
        // Initialize native ROS2 bridge (alternative to WebSocket)
        nativeROS2Bridge = ROS2NativeBridge()
        
        // Setup gamepad button handling
        setupGamepadButtonHandling()
    }
    
    private func setupGamepadButtonHandling() {
        // Monitor gamepad button presses
        Timer.publish(every: 0.016, on: .main, in: .common) // ~60Hz
            .autoconnect()
            .sink { _ in
                processGamepadButtons()
            }
            .store(in: &cancellables)
    }
    
    private func processGamepadButtons() {
        guard let robotControlManager = robotControlManager else { return }
        
        // Check for button presses
        for button in GamepadManager.Button.allCases {
            if gamepadManager.isButtonPressed(button) {
                let action = inputCoordinator?.handleButtonPress(button) ?? .none
                robotControlManager.handleButtonAction(action)
            }
        }
    }
    
    private func setupROS2Connection() {
        print("🔌 Setting up ROS2 connection for robot: \(appModel.selectedRobot.name)")
        print("🔌 Robot IP: \(appModel.selectedRobot.ipAddress)")
        
        // Update the existing ROS2WebSocketManager with selected robot's IP
        ros2Manager.updateServerIP(appModel.selectedRobot.ipAddress)
        print("🤖 Updated existing ROS2WebSocketManager instance for \(appModel.selectedRobot.ipAddress)")
        
        // Connect to ROS2 WebSocket
        print("🔌 Initiating WebSocket connection...")
        ros2Manager.connect()
        
        // Subscribe to connection state changes
        Task {
            for await state in ros2Manager.$connectionState.values {
                print("🔌 ROS2 connection state changed: \(state)")
                appModel.updateROS2ConnectionState(state)
                
            }
        }
        
        // Subscribe to obstacle warnings
        ros2Manager.subscribe(to: "/obstacle_warning", messageType: "std_msgs/Bool") { message in
            if let data = message as? [String: Any],
               let warning = data["data"] as? Bool {
                Task { @MainActor in
                    appModel.setObstacleWarning(warning)
                }
            }
        }
        
        // Load available actions
        actionManager?.loadAvailableActions()
        
        // Connect native ROS2 bridge as alternative
        nativeROS2Bridge?.connect()
    }
}

// MARK: - Control Panel View
struct ControlPanelView: View {
    @Environment(AppModel.self) var appModel
    let ros2Manager: ROS2WebSocketManager
    let gamepadManager: GamepadManager
    let inputCoordinator: InputCoordinator?
    let robotControlManager: RobotControlManager?
    
    @State private var leftJoystick = JoystickState()
    @State private var rightJoystick = JoystickState()
    
    var body: some View {
        HStack(spacing: 20) {
            // Left joystick (movement)
            JoystickView(
                state: $leftJoystick,
                label: "Movement",
                color: .blue
            )
            .frame(width: 80, height: 80)
            
            // Center controls
            VStack(spacing: 8) {
                // Speed control
                VStack {
                    Text("Speed: \(robotControlManager?.speed ?? 25)%")
                        .font(.caption)
                    Slider(value: Binding(
                        get: { Double(robotControlManager?.speed ?? 25) },
                        set: { robotControlManager?.setSpeed(Int($0)) }
                    ), in: 0...100)
                    .frame(width: 120)
                }
                
                // Mode toggle
                Button(action: {
                    robotControlManager?.setControlMode(robotControlManager?.controlMode == .manual ? .arm : .manual)
                }) {
                    Text((robotControlManager?.controlMode ?? .manual) == .manual ? "🚗 Manual" : "🤖 Arm")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background((robotControlManager?.controlMode ?? .manual) == .manual ? .blue : .orange, in: Capsule())
                }
                
                // Emergency stop
                Button(action: {
                    robotControlManager?.setEmergencyStop(!(robotControlManager?.emergencyStop ?? false))
                }) {
                    Text((robotControlManager?.emergencyStop ?? false) ? "STOPPED" : "E-STOP")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background((robotControlManager?.emergencyStop ?? false) ? .red : .gray, in: Capsule())
                }
            }
            
            // Right joystick (rotation/arm)
            JoystickView(
                state: $rightJoystick,
                label: (robotControlManager?.controlMode ?? .manual) == .manual ? "Rotation" : "Arm",
                color: (robotControlManager?.controlMode ?? .manual) == .manual ? .green : .orange
            )
            .frame(width: 80, height: 80)
        }
        .onChange(of: leftJoystick.values.x) { _, _ in
            updateHandInputs()
        }
        .onChange(of: leftJoystick.values.y) { _, _ in
            updateHandInputs()
        }
        .onChange(of: rightJoystick.values.x) { _, _ in
            updateHandInputs()
        }
        .onChange(of: rightJoystick.values.y) { _, _ in
            updateHandInputs()
        }
    }
    
    private func updateHandInputs() {
        guard let inputCoordinator = inputCoordinator else { return }
        
        // Update hand gesture inputs
        inputCoordinator.updateHandMovement(
            forward: leftJoystick.values.y,
            strafe: -leftJoystick.values.x
        )
        
        inputCoordinator.updateHandRotation(-rightJoystick.values.x)
        
        inputCoordinator.updateHandArmInput(
            x: rightJoystick.values.x,
            y: rightJoystick.values.y
        )
    }
}

// MARK: - Joystick State (using the one from VirtualJoystickView)

// MARK: - Joystick View
struct JoystickView: View {
    @Binding var state: JoystickState
    let label: String
    let color: Color
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    private let maxDistance: CGFloat = 30
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ZStack {
                // Joystick base
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 2)
                    )
                
                // Joystick knob
                Circle()
                    .fill(color)
                    .frame(width: 20, height: 20)
                    .offset(dragOffset)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isDragging)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        
                        // Limit drag distance
                        let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                        if distance <= maxDistance {
                            dragOffset = value.translation
                        } else {
                            let angle = atan2(value.translation.height, value.translation.width)
                            dragOffset = CGSize(
                                width: Foundation.cos(angle) * maxDistance,
                                height: Foundation.sin(angle) * maxDistance
                            )
                        }
                        
                        // Update joystick values (-1 to 1)
                        state.values = (
                            x: Double(dragOffset.width / maxDistance),
                            y: -Double(dragOffset.height / maxDistance) // Invert Y for intuitive control
                        )
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragOffset = .zero
                        state.values = (0, 0)
                    }
            )
        }
    }
}

#Preview(immersionStyle: .progressive) {
    SpatialTeleopView()
        .environment(AppModel())
}

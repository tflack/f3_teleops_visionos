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
    @ObservedObject private var ros2Manager = ROS2WebSocketManager.shared
    @StateObject private var gamepadManager = GamepadManager()
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
        // Update IP for singleton instance
        ROS2WebSocketManager.shared.updateServerIP(AppModel.Robot.alpha.ipAddress)
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "robot")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    
                    Text("\(appModel.selectedRobot.displayName) Control")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Connection status (more prominent)
                HStack(spacing: 8) {
                    Circle()
                        .fill(ros2Manager.isConnected ? .green : .red)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Robot Connection")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(ros2Manager.isConnected ? "Connected" : "Disconnected")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(ros2Manager.isConnected ? .green : .red)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                
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
            .padding(.horizontal, 20)
            .padding(.top, 30)
            .padding(.bottom, 20)
            
            // Main content: Left side (controls/info) + Right side (camera column)
            HStack(alignment: .top, spacing: 0) {
                // Left side: Control panel
                ScrollView {
                    VStack(spacing: 16) {
                        // Connection Status
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(ros2Manager.isConnected ? .green : .red)
                                    .frame(width: 8, height: 8)
                                Text(ros2Manager.isConnected ? "Robot" : "Robot")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(6)
                            .background(ros2Manager.isConnected ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            .cornerRadius(4)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(gamepadManager.isConnected ? .green : .gray)
                                    .frame(width: 8, height: 8)
                                Text(gamepadManager.isConnected ? "Gamepad" : "Gamepad")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(6)
                            .background(gamepadManager.isConnected ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        }
                        
                        Divider()
                        
                        // Joysticks Display
                        HStack(spacing: 16) {
                            VStack {
                                Text("LEFT")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.bold)
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                    Circle()
                                        .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2]))
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 20, height: 20)
                                        .offset(
                                            x: CGFloat(gamepadManager.leftStick.x) * 30,
                                            y: -CGFloat(gamepadManager.leftStick.y) * 30
                                        )
                                }
                                Text("X: \(String(format: "%.2f", gamepadManager.leftStick.x)) Y: \(String(format: "%.2f", gamepadManager.leftStick.y))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .monospaced()
                            }
                            
                            VStack {
                                Text("RIGHT")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.bold)
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                    Circle()
                                        .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2]))
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 20, height: 20)
                                        .offset(
                                            x: CGFloat(gamepadManager.rightStick.x) * 30,
                                            y: -CGFloat(gamepadManager.rightStick.y) * 30
                                        )
                                }
                                Text("X: \(String(format: "%.2f", gamepadManager.rightStick.x)) Y: \(String(format: "%.2f", gamepadManager.rightStick.y))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .monospaced()
                            }
                        }
                        
                        Divider()
                        
                        // Speed Control
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("SPEED")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("\(robotControlManager?.speed ?? 25)%")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                            }
                            Slider(value: Binding(
                                get: { Double(robotControlManager?.speed ?? 25) },
                                set: { robotControlManager?.setSpeed(Int($0)) }
                            ), in: 0...100)
                            .tint(.blue)
                        }
                        
                        Divider()
                        
                        // Mode Control
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MODE")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.bold)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    robotControlManager?.setControlMode(.manual)
                                }) {
                                    HStack {
                                        Image(systemName: "car.fill")
                                        Text("Move")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor((robotControlManager?.controlMode ?? .manual) == .manual ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background((robotControlManager?.controlMode ?? .manual) == .manual ? Color.blue : Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    robotControlManager?.setControlMode(.arm)
                                }) {
                                    HStack {
                                        Image(systemName: "hand.raised.fill")
                                        Text("Arm")
                                    }
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor((robotControlManager?.controlMode ?? .manual) == .arm ? .white : .orange)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background((robotControlManager?.controlMode ?? .manual) == .arm ? Color.orange : Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Actions Dropdown
                        if let actionManager = actionManager {
                            ActionMenuView(actionManager: actionManager)
                        }
                        
                        Divider()
                        
                        // Emergency Stop
                        Button(action: {
                            let newState = !(robotControlManager?.emergencyStop ?? false)
                            robotControlManager?.setEmergencyStop(newState)
                        }) {
                            HStack {
                                Image(systemName: "hand.raised.slash.fill")
                                    .font(.title3)
                                Text((robotControlManager?.emergencyStop ?? false) ? "STOPPED" : "E-STOP")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor((robotControlManager?.emergencyStop ?? false) ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background((robotControlManager?.emergencyStop ?? false) ? Color.red : Color.red.opacity(0.3))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                        }
                        
                        // Safety Override & Obstacle Warning
                        if appModel.obstacleWarning {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.yellow)
                                Text("Obstacle Detected")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                }
                .frame(width: 400)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .padding(.leading, 20)
                
                Spacer()
                
                // Right side: Camera column
                ScrollView {
                    VStack(spacing: 4) {
    
                        // RGB Camera Feed
                        CameraFeedView(ros2Manager: ros2Manager, selectedCamera: .constant(.rgb))
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 720, height: 405)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        
                        // Heatmap Camera Feed
                        CameraFeedView(ros2Manager: ros2Manager, selectedCamera: .constant(.heatmap))
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 720, height: 405)
                            .clipped()
                            .cornerRadius(12)
                            .shadow(radius: 5)

                   // SLAM Map
                        SLAMMapView(ros2Manager: ros2Manager)
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 720, height: 405)
                            .clipped()
                            .background(.black.opacity(0.8))
                            .cornerRadius(12)
                            .shadow(radius: 5)
                        
                        // 3D Point Cloud
                        PointCloudView(ros2Manager: ros2Manager)
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 720, height: 405)
                            .clipped()
                            .background(.black.opacity(0.8))
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    
                    }
                    .padding(.bottom, 20)
                }
                .frame(width: 780)
                .padding(.trailing, 20)
            }
        }
        .frame(minWidth: 2400, minHeight: 1600)
        .edgesIgnoringSafeArea(.top) // Allow content to extend into safe area at top
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
                
                // Load actions when connected
                if case .connected = state {
                    print("🔌 WebSocket connected, loading actions...")
                    actionManager?.loadAvailableActions()
                }
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

// MARK: - Action Menu View
struct ActionMenuView: View {
    @ObservedObject var actionManager: ActionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIONS")
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.bold)
            
            if let actions = actionManager.availableActions {
                Menu {
                    ForEach(actions.allActions, id: \.self) { action in
                        Button(action) {
                            actionManager.executeAction(action)
                        }
                    }
                } label: {
                    HStack {
                        Text("Select Action")
                            .font(.caption)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(6)
                }
                
                Text("\(actions.totalCount) actions available")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    Text(actionManager.isLoading ? "Loading actions..." : "No actions available")
                        .font(.caption)
                    Spacer()
                }
                .foregroundColor(.gray)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
}

#Preview(immersionStyle: .progressive) {
    SpatialTeleopView()
        .environment(AppModel())
}

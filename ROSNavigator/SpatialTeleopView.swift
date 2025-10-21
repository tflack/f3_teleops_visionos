//
//  SpatialTeleopView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import RealityKit
import Combine

struct SpatialTeleopView: View {
    @Environment(AppModel.self) var appModel
    @State private var ros2Manager = ROS2WebSocketManager()
    @State private var gamepadManager = GamepadManager()
    @State private var inputCoordinator: InputCoordinator?
    @State private var robotControlManager: RobotControlManager?
    @State private var actionManager: ActionManager?
    @State private var windowCoordinator = WindowCoordinator()
    @State private var nativeROS2Bridge: ROS2NativeBridge?
    
    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
            }
        } update: { content in
            // Update content if needed
        }
        .overlay(alignment: .bottom) {
            // Main control panel at bottom
            ControlPanelView(
                ros2Manager: ros2Manager,
                gamepadManager: gamepadManager,
                inputCoordinator: inputCoordinator,
                robotControlManager: robotControlManager
            )
                .frame(maxWidth: 600, maxHeight: 200)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()
        }
        .overlay(alignment: .topLeading) {
            // Status panel at top left
            StatusPanelView()
                .frame(maxWidth: 300, maxHeight: 150)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding()
        }
        .overlay(alignment: .topTrailing) {
            // Alerts panel at top right
            AlertsPanelView()
                .frame(maxWidth: 250, maxHeight: 100)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding()
        }
        .overlay(alignment: .center) {
            // Main camera feed in center
            CameraFeedView(ros2Manager: ros2Manager)
                .frame(width: 640, height: 360)
                .background(.black, in: RoundedRectangle(cornerRadius: 8))
        }
        .overlay(alignment: .leading) {
            // LIDAR and SLAM visualizations on left
            VStack(spacing: 16) {
                LidarVisualizationView(ros2Manager: ros2Manager)
                    .frame(width: 300, height: 300)
                    .background(.black, in: RoundedRectangle(cornerRadius: 8))
                
                SLAMMapView(ros2Manager: ros2Manager)
                    .frame(width: 300, height: 200)
                    .background(.black, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .overlay(alignment: .trailing) {
            // Point cloud viewer on right
            PointCloudView(ros2Manager: ros2Manager)
                .frame(width: 400, height: 400)
                .background(.black, in: RoundedRectangle(cornerRadius: 8))
                .padding()
        }
        .overlay(alignment: .bottomTrailing) {
            // Debug console
            DebugConsoleView(
                ros2Manager: ros2Manager,
                gamepadManager: gamepadManager
            )
            .frame(maxWidth: 400, maxHeight: 300)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
        }
        .onAppear {
            setupManagers()
            setupROS2Connection()
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
            .sink { [weak self] _ in
                self?.processGamepadButtons()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
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
        // Connect to ROS2 WebSocket
        ros2Manager.connect()
        
        // Subscribe to connection state changes
        Task {
            for await state in ros2Manager.$connectionState.values {
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
        .onChange(of: leftJoystick.values) { _, newValues in
            updateHandInputs()
        }
        .onChange(of: rightJoystick.values) { _, newValues in
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

// MARK: - Joystick State
struct JoystickState {
    var values: (x: Double, y: Double) = (0, 0)
}

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
                        let distance = sqrt(pow(value.translation.x, 2) + pow(value.translation.y, 2))
                        if distance <= maxDistance {
                            dragOffset = value.translation
                        } else {
                            let angle = atan2(value.translation.y, value.translation.x)
                            dragOffset = CGSize(
                                width: cos(angle) * maxDistance,
                                height: sin(angle) * maxDistance
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

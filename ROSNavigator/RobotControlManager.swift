//
//  RobotControlManager.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine

@MainActor
class RobotControlManager: ObservableObject {
    @Published var speed: Int = 25
    @Published var controlMode: AppModel.ControlMode = .manual
    @Published var emergencyStop: Bool = false
    @Published var safetyOverride: Bool = false
    @Published var armPosition = ArmPosition()
    
    private let ros2Manager: ROS2WebSocketManager
    private let inputCoordinator: InputCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    // Control state
    private var lastMovementCommand: Twist?
    private var lastArmCommand: ServoControl?
    private var isMoving = false
    
    // Throttling
    private let movementThrottleInterval: TimeInterval = 0.05 // 20Hz
    private let armThrottleInterval: TimeInterval = 0.1 // 10Hz
    private var lastMovementTime: Date = Date()
    private var lastArmTime: Date = Date()
    
    init(ros2Manager: ROS2WebSocketManager, inputCoordinator: InputCoordinator) {
        self.ros2Manager = ros2Manager
        self.inputCoordinator = inputCoordinator
        
        setupInputHandling()
        setupControlLoop()
    }
    
    private func setupInputHandling() {
        // Monitor input changes
        Publishers.CombineLatest4(
            inputCoordinator.$finalMovement,
            inputCoordinator.$finalRotation,
            inputCoordinator.$finalArmInput,
            $controlMode
        )
        .sink { [weak self] movement, rotation, armInput, mode in
            self?.processInputs(movement: movement, rotation: rotation, armInput: armInput, mode: mode)
        }
        .store(in: &cancellables)
        
        // Monitor speed changes
        $speed
            .sink { [weak self] _ in
                self?.sendMovementCommand()
            }
            .store(in: &cancellables)
        
        // Monitor emergency stop
        $emergencyStop
            .sink { [weak self] enabled in
                if enabled {
                    self?.sendStopCommand()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupControlLoop() {
        // Continuous control loop for smooth operation
        Timer.publish(every: 0.016, on: .main, in: .common) // ~60Hz
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateControlLoop()
            }
            .store(in: &cancellables)
    }
    
    private func processInputs(
        movement: (forward: Double, strafe: Double),
        rotation: Double,
        armInput: (x: Double, y: Double),
        mode: AppModel.ControlMode
    ) {
        if emergencyStop {
            return
        }
        
        if mode == .manual {
            // Send movement command
            sendMovementCommand()
        } else {
            // Send arm control command
            updateArmPosition(from: armInput)
        }
    }
    
    private func updateControlLoop() {
        // Check if we need to send stop command
        if isMoving && !inputCoordinator.hasActiveInput && !emergencyStop {
            sendStopCommand()
        }
    }
    
    private func sendMovementCommand() {
        guard !emergencyStop else {
            sendStopCommand()
            return
        }
        
        let now = Date()
        guard now.timeIntervalSince(lastMovementTime) >= movementThrottleInterval else {
            return
        }
        
        let movement = inputCoordinator.finalMovement
        let rotation = inputCoordinator.finalRotation
        
        // Check if there's actual movement
        let hasMovement = abs(movement.forward) > 0.01 || abs(movement.strafe) > 0.01 || abs(rotation) > 0.01
        
        let twist: Twist
        if hasMovement {
            twist = Twist.movement(
                forward: movement.forward * Double(speed) / 100.0,
                strafe: movement.strafe * Double(speed) / 100.0,
                rotation: controlMode == .manual ? rotation * Double(speed) / 100.0 : 0.0
            )
            isMoving = true
        } else {
            twist = Twist.stop()
            isMoving = false
        }
        
        // Only send if different from last command
        if !isSameTwist(twist, lastMovementCommand) {
            ros2Manager.publishTwist(to: "/cmd_vel_user", twist: twist)
            lastMovementCommand = twist
            lastMovementTime = now
            
            print("📡 Movement: forward=\(String(format: "%.3f", twist.linear.x)), strafe=\(String(format: "%.3f", twist.linear.y)), rotation=\(String(format: "%.3f", twist.angular.z))")
        }
    }
    
    private func sendStopCommand() {
        let twist = Twist.stop()
        ros2Manager.publishTwist(to: "/cmd_vel_user", twist: twist)
        lastMovementCommand = twist
        isMoving = false
        
        print("🛑 Stop command sent")
    }
    
    private func updateArmPosition(from input: (x: Double, y: Double)) {
        let now = Date()
        guard now.timeIntervalSince(lastArmTime) >= armThrottleInterval else {
            return
        }
        
        let baseSensitivity = 2.0
        let interpolationFactor = max(0, min(1, (-input.y + 1) / 2))
        
        // Calculate target positions based on joystick input
        let targetJoint2 = 750 - (interpolationFactor * (750 - 225))
        let targetJoint3 = 0 + (interpolationFactor * (225 - 0))
        let targetJoint4 = 375 + (interpolationFactor * (400 - 375))
        
        // Apply X-axis rotation
        let baseRotationChange = input.x * baseSensitivity * 2.0
        let wristRotationChange = input.x * baseSensitivity * 0.3
        
        // Update arm positions with smoothing
        armPosition.updatePosition(jointId: 1, targetPosition: Int(500 - baseRotationChange))
        armPosition.updatePosition(jointId: 2, targetPosition: Int(targetJoint2))
        armPosition.updatePosition(jointId: 3, targetPosition: Int(targetJoint3))
        armPosition.updatePosition(jointId: 4, targetPosition: Int(targetJoint4))
        armPosition.updatePosition(jointId: 5, targetPosition: Int(500 - wristRotationChange))
        
        // Send arm control command
        let servoControl = armPosition.toServoControl()
        ros2Manager.publishServoControl(to: "/servo_controller", servoControl: servoControl)
        lastArmCommand = servoControl
        lastArmTime = now
        
        print("🤖 Arm control: J1=\(armPosition.joint1), J2=\(armPosition.joint2), J3=\(armPosition.joint3), J4=\(armPosition.joint4), J5=\(armPosition.joint5), Grip=\(armPosition.gripper)")
    }
    
    // MARK: - Control Actions
    
    func handleButtonAction(_ action: ButtonAction) {
        switch action {
        case .emergencyStop:
            emergencyStop.toggle()
            if emergencyStop {
                speed = 0
            }
            
        case .resetPosition:
            if controlMode == .arm {
                armPosition.reset()
            } else {
                // Reset movement inputs
                inputCoordinator.updateHandMovement(forward: 0, strafe: 0)
                inputCoordinator.updateHandRotation(0)
            }
            
        case .gripperClose:
            armPosition.updatePosition(jointId: 10, targetPosition: max(0, armPosition.gripper - 10))
            
        case .gripperOpen:
            armPosition.updatePosition(jointId: 10, targetPosition: min(1000, armPosition.gripper + 10))
            
        case .decreaseSpeed:
            speed = max(0, speed - 10)
            
        case .increaseSpeed:
            speed = min(100, speed + 10)
            
        case .toggleArmMode:
            controlMode = (controlMode == .manual) ? .arm : .manual
            
        case .toggleSafetyOverride:
            safetyOverride.toggle()
            // Publish safety override status
            ros2Manager.publish(to: "/safety_override", message: ["data": safetyOverride])
            
        case .wristRotateLeft:
            armPosition.updatePosition(jointId: 5, targetPosition: max(0, armPosition.joint5 - 10))
            
        case .wristRotateRight:
            armPosition.updatePosition(jointId: 5, targetPosition: min(1000, armPosition.joint5 + 10))
            
        case .executeAction(let actionName):
            executeAction(actionName)
            
        case .none:
            break
        }
    }
    
    private func executeAction(_ actionName: String) {
        let actionMessage = ["data": actionName]
        ros2Manager.publish(to: "/execute_action", message: actionMessage)
        print("🚀 Executing action: \(actionName)")
    }
    
    // MARK: - Utility Methods
    
    private func isSameTwist(_ a: Twist, _ b: Twist?) -> Bool {
        guard let b = b else { return false }
        
        return abs(a.linear.x - b.linear.x) < 0.001 &&
               abs(a.linear.y - b.linear.y) < 0.001 &&
               abs(a.linear.z - b.linear.z) < 0.001 &&
               abs(a.angular.x - b.angular.x) < 0.001 &&
               abs(a.angular.y - b.angular.y) < 0.001 &&
               abs(a.angular.z - b.angular.z) < 0.001
    }
    
    func setSpeed(_ newSpeed: Int) {
        speed = max(0, min(100, newSpeed))
    }
    
    func setControlMode(_ mode: AppModel.ControlMode) {
        controlMode = mode
    }
    
    func setEmergencyStop(_ enabled: Bool) {
        emergencyStop = enabled
        if enabled {
            speed = 0
        }
    }
    
    func setSafetyOverride(_ enabled: Bool) {
        safetyOverride = enabled
        ros2Manager.publish(to: "/safety_override", message: ["data": enabled])
    }
}

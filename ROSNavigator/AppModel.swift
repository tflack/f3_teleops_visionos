//
//  AppModel.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed
    
    // MARK: - ROS2 Connection State
    var ros2ConnectionState: ROS2WebSocketManager.ConnectionState = .disconnected
    var isROS2Connected: Bool = false
    var lastROS2Error: String?
    
    // MARK: - Robot Status
    enum RobotStatus {
        case online
        case offline
        case event
    }
    
    enum ControlMode {
        case manual
        case arm
    }
    
    var selectedRobot: Robot = Robot.alpha
    var robotStatus: RobotStatus = .offline
    var controlMode: ControlMode = .manual
    var speed: Int = 25
    var emergencyStop: Bool = false
    var safetyOverride: Bool = false
    var obstacleWarning: Bool = false
    
    // MARK: - Stream Health
    var streamHealth: String = "Degraded"
    var cameraCount: Int = 0
    
    // MARK: - Robot Definitions
    struct Robot: Identifiable, CaseIterable, Hashable {
        let id: Int
        let name: String
        let ipAddress: String
        let cameras: [String]
        
        var displayName: String {
            return name
        }
        
        static let alpha = Robot(
            id: 1,
            name: "F3 Rover Alpha",
            ipAddress: "192.168.1.49",
            cameras: ["RGB Camera", "Heat Map", "IR Camera"]
        )
        
        static let beta = Robot(
            id: 2,
            name: "F3 Rover Beta",
            ipAddress: "192.168.1.73",
            cameras: ["RGB Camera", "Depth Cam"]
        )
        
        static let gamma = Robot(
            id: 3,
            name: "F3 Rover Gamma",
            ipAddress: "192.168.1.92",
            cameras: ["RGB Camera", "IR Camera"]
        )
        
        static let delta = Robot(
            id: 4,
            name: "F3 Rover Delta",
            ipAddress: "192.168.1.58",
            cameras: []
        )
        
        static var allCases: [Robot] = [.alpha, .beta, .gamma, .delta]
    }
    
    // MARK: - Methods
    func updateROS2ConnectionState(_ state: ROS2WebSocketManager.ConnectionState) {
        ros2ConnectionState = state
        switch state {
        case .connected:
            isROS2Connected = true
        default:
            isROS2Connected = false
        }
        
        // Update robot status based on connection
        if isROS2Connected {
            robotStatus = .online
            streamHealth = "Nominal"
        } else {
            robotStatus = .offline
            streamHealth = "Degraded"
        }
    }
    
    func updateStreamHealth(_ health: String) {
        streamHealth = health
    }
    
    func updateCameraCount(_ count: Int) {
        cameraCount = count
        if count > 0 && isROS2Connected {
            streamHealth = "Nominal"
        } else {
            streamHealth = "Degraded"
        }
    }
    
    func toggleControlMode() {
        controlMode = (controlMode == .manual) ? .arm : .manual
    }
    
    func setEmergencyStop(_ enabled: Bool) {
        emergencyStop = enabled
        if enabled {
            speed = 0
        }
    }
    
    func setSafetyOverride(_ enabled: Bool) {
        safetyOverride = enabled
    }
    
    func setObstacleWarning(_ enabled: Bool) {
        obstacleWarning = enabled
    }
}

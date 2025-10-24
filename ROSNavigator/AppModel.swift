//
//  AppModel.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import Network

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
    
    // MARK: - Robot Connection Status
    var robotConnectionStatuses: [Int: Robot.ConnectionStatus] = [:]
    
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
        
        enum ConnectionStatus: String, CaseIterable {
            case online = "online"
            case offline = "offline"
            case unknown = "unknown"
            case checking = "checking"
            
            var color: Color {
                switch self {
                case .online:
                    return .green
                case .offline:
                    return .red
                case .unknown:
                    return .gray
                case .checking:
                    return .orange
                }
            }
        }
        
        static let alpha = Robot(
            id: 1,
            name: "F3 Rover Alpha",
            ipAddress: "192.168.1.49",
            cameras: ["RGB Camera", "Heat Map", "IR Camera", "Depth Camera"]
        )
        
        static let beta = Robot(
            id: 2,
            name: "F3 Rover Beta",
            ipAddress: "192.168.1.73",
            cameras: ["RGB Camera", "Depth Camera", "Thermal Camera"]
        )
        
        static let gamma = Robot(
            id: 3,
            name: "F3 Rover Gamma",
            ipAddress: "192.168.1.92",
            cameras: ["RGB Camera", "IR Camera", "Stereo Camera"]
        )
        
        static let delta = Robot(
            id: 4,
            name: "F3 Rover Delta",
            ipAddress: "192.168.1.58",
            cameras: ["RGB Camera", "Depth Camera", "LIDAR"]
        )
        
        static var allCases: [Robot] = [.alpha, .beta, .gamma, .delta]
    }
    
    // MARK: - Methods
    func updateROS2ConnectionState(_ state: ROS2WebSocketManager.ConnectionState) {
        let previousState = ros2ConnectionState
        ros2ConnectionState = state
        
        print("🔄 AppModel ROS2 connection state changed: \(previousState) -> \(state)")
        
        switch state {
        case .connected:
            isROS2Connected = true
            print("✅ ROS2 connected successfully")
        default:
            isROS2Connected = false
            print("❌ ROS2 disconnected or error")
        }
        
        // Update robot status based on connection
        if isROS2Connected {
            robotStatus = .online
            streamHealth = "Nominal"
            print("🤖 Robot status updated to: ONLINE")
        } else {
            robotStatus = .offline
            streamHealth = "Degraded"
            print("🤖 Robot status updated to: OFFLINE")
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
    
    // MARK: - Connection Checking
    
    func checkRobotConnections() {
        print("🔍 Starting connection checks for \(Robot.allCases.count) robots")
        for robot in Robot.allCases {
            print("🔍 Checking connection for \(robot.name) at \(robot.ipAddress)")
            Task {
                await checkRobotConnection(robot)
            }
        }
    }
    
    private func checkRobotConnection(_ robot: Robot) async {
        print("🔍 Starting connection check for \(robot.name) at \(robot.ipAddress)")
        
        // Update status to checking
        updateRobotConnectionStatus(robot.id, status: .checking)
        
        // Perform async connection check
        let isOnline = await performConnectionCheck(ipAddress: robot.ipAddress)
        
        // Update status based on result
        let status: Robot.ConnectionStatus = isOnline ? .online : .offline
        updateRobotConnectionStatus(robot.id, status: status)
        
        print("🔍 Connection check completed for \(robot.name): \(status.rawValue)")
    }
    
    private func updateRobotConnectionStatus(_ robotId: Int, status: Robot.ConnectionStatus) {
        robotConnectionStatuses[robotId] = status
    }
    
    func getRobotConnectionStatus(_ robotId: Int) -> Robot.ConnectionStatus {
        return robotConnectionStatuses[robotId] ?? .unknown
    }
    
    private func performConnectionCheck(ipAddress: String) async -> Bool {
        print("🔍 Performing connection check to \(ipAddress):9090")
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "ConnectionCheck")
            var hasResumed = false
            
            let resumeOnce: (Bool) -> Void = { result in
                if !hasResumed {
                    hasResumed = true
                    print("🔍 Connection check result for \(ipAddress): \(result ? "ONLINE" : "OFFLINE")")
                    continuation.resume(returning: result)
                }
            }
            
            monitor.pathUpdateHandler = { path in
                if path.status == .satisfied {
                    // Network is available, now check if we can reach the specific IP
                    let connection = NWConnection(
                        host: NWEndpoint.Host(ipAddress),
                        port: NWEndpoint.Port(integerLiteral: 9090), // ROS2 WebSocket port
                        using: .tcp
                    )
                    
                    connection.stateUpdateHandler = { state in
                        switch state {
                        case .ready:
                            connection.cancel()
                            monitor.cancel()
                            resumeOnce(true)
                        case .failed(_), .cancelled:
                            connection.cancel()
                            monitor.cancel()
                            resumeOnce(false)
                        default:
                            break
                        }
                    }
                    
                    connection.start(queue: queue)
                    
                    // Timeout after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        connection.cancel()
                        monitor.cancel()
                        resumeOnce(false)
                    }
                } else {
                    monitor.cancel()
                    resumeOnce(false)
                }
            }
            
            monitor.start(queue: queue)
        }
    }
}

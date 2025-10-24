//
//  ROS2NativeBridge.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine

/// Native ROS2 bridge using DDS (Data Distribution Service)
/// This provides an alternative to WebSocket for direct ROS2 communication
@MainActor
class ROS2NativeBridge: ObservableObject {
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    // DDS Domain and Node
    private var domainId: Int = 0
    private var node: ROS2Node?
    private var context: ROS2Context?
    
    // Publishers and Subscribers
    private var publishers: [String: ROS2Publisher] = [:]
    private var subscribers: [String: ROS2Subscriber] = [:]
    private var services: [String: ROS2ServiceClient] = [:]
    
    // Message handlers
    private var messageHandlers: [String: (Any) -> Void] = [:]
    
    // Connection settings
    private let robotIP: String
    private let domainIdKey = "ROS_DOMAIN_ID"
    
    init(robotIP: String = "192.168.1.49") {
        self.robotIP = robotIP
        setupEnvironment()
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.disconnect()
        }
    }
    
    // MARK: - Environment Setup
    
    private func setupEnvironment() {
        // Set ROS2 environment variables
        setenv("ROS_DOMAIN_ID", "0", 1)
        setenv("RMW_IMPLEMENTATION", "rmw_fastrtps_cpp", 1)
        
        // Set DDS configuration for network discovery
        let ddsConfig = """
        <?xml version="1.0" encoding="UTF-8" ?>
        <profiles xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
            <transport_descriptors>
                <transport_descriptor>
                    <transport_id>udp_transport</transport_id>
                    <type>UDPv4</type>
                    <interfaceWhiteList>
                        <address>\(robotIP)</address>
                    </interfaceWhiteList>
                </transport_descriptor>
            </transport_descriptors>
        </profiles>
        """
        
        // Write DDS configuration to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let configFile = tempDir.appendingPathComponent("dds_config.xml")
        
        do {
            try ddsConfig.write(to: configFile, atomically: true, encoding: .utf8)
            setenv("FASTRTPS_DEFAULT_PROFILES_FILE", configFile.path, 1)
        } catch {
            print("⚠️ Failed to write DDS config: \(error)")
        }
    }
    
    // MARK: - Connection Management
    
    func connect() {
        guard case .disconnected = connectionState else { return }
        
        connectionState = .connecting
        lastError = nil
        
        Task {
            do {
                try await initializeROS2()
                connectionState = .connected
                isConnected = true
                print("✅ Native ROS2 bridge connected")
            } catch {
                connectionState = .error(error.localizedDescription)
                lastError = error.localizedDescription
                isConnected = false
                print("❌ Native ROS2 bridge connection failed: \(error)")
            }
        }
    }
    
    func disconnect() {
        // Clean up publishers and subscribers
        publishers.removeAll()
        subscribers.removeAll()
        services.removeAll()
        messageHandlers.removeAll()
        
        // Shutdown ROS2 context
        context = nil
        node = nil
        
        connectionState = .disconnected
        isConnected = false
        
        print("🔌 Native ROS2 bridge disconnected")
    }
    
    private func initializeROS2() async throws {
        // Initialize ROS2 context
        context = try ROS2Context(domainId: domainId)
        
        // Create ROS2 node
        node = try ROS2Node(name: "visionos_teleop", context: context!)
        
        print("🔧 ROS2 context and node initialized")
    }
    
    // MARK: - Topic Management
    
    func subscribe(to topic: String, messageType: String, handler: @escaping (Any) -> Void) {
        guard node != nil else {
            print("⚠️ ROS2 node not initialized")
            return
        }
        
        messageHandlers[topic] = handler
        
        do {
            let subscriber = try createSubscriber(for: topic, messageType: messageType)
            subscribers[topic] = subscriber
            print("📡 Subscribed to \(topic) (\(messageType))")
        } catch {
            print("❌ Failed to subscribe to \(topic): \(error)")
        }
    }
    
    func unsubscribe(from topic: String) {
        subscribers.removeValue(forKey: topic)
        messageHandlers.removeValue(forKey: topic)
        print("📡 Unsubscribed from \(topic)")
    }
    
    func publish(to topic: String, message: [String: Any]) {
        guard node != nil else {
            print("⚠️ ROS2 node not initialized")
            return
        }
        
        do {
            let publisher = try getOrCreatePublisher(for: topic)
            let rosMessage = try convertToROSMessage(message, for: topic)
            try publisher.publish(rosMessage)
        } catch {
            print("❌ Failed to publish to \(topic): \(error)")
        }
    }
    
    func publishTwist(to topic: String, twist: Twist) {
        let twistDict: [String: Any] = [
            "linear": [
                "x": twist.linear.x,
                "y": twist.linear.y,
                "z": twist.linear.z
            ],
            "angular": [
                "x": twist.angular.x,
                "y": twist.angular.y,
                "z": twist.angular.z
            ]
        ]
        
        publish(to: topic, message: twistDict)
    }
    
    func publishServoControl(to topic: String, servoControl: ServoControl) {
        let servoDict: [String: Any] = [
            "duration": servoControl.duration,
            "position_unit": servoControl.positionUnit,
            "position": servoControl.position.map { pos in
                [
                    "id": pos.id,
                    "position": pos.position
                ]
            }
        ]
        
        publish(to: topic, message: servoDict)
    }
    
    // MARK: - Service Calls
    
    func callService(service: String, request: [String: Any] = [:], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard node != nil else {
            completion(.failure(ROS2Error.nodeNotInitialized))
            return
        }
        
        Task {
            do {
                let serviceClient = try createServiceClient(for: service)
                let response = try await serviceClient.call(request)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createSubscriber(for topic: String, messageType: String) throws -> ROS2Subscriber {
        guard let node = node else {
            throw ROS2Error.nodeNotInitialized
        }
        
        let subscriber = try ROS2Subscriber(
            node: node,
            topic: topic,
            messageType: messageType
        ) { [weak self] message in
            Task { @MainActor in
                self?.handleMessage(topic: topic, message: message)
            }
        }
        
        return subscriber
    }
    
    private func getOrCreatePublisher(for topic: String) throws -> ROS2Publisher {
        if let existingPublisher = publishers[topic] {
            return existingPublisher
        }
        
        guard let node = node else {
            throw ROS2Error.nodeNotInitialized
        }
        
        let messageType = getMessageType(for: topic)
        let publisher = try ROS2Publisher(
            node: node,
            topic: topic,
            messageType: messageType
        )
        
        publishers[topic] = publisher
        return publisher
    }
    
    private func createServiceClient(for service: String) throws -> ROS2ServiceClient {
        guard let node = node else {
            throw ROS2Error.nodeNotInitialized
        }
        
        let serviceType = getServiceType(for: service)
        return try ROS2ServiceClient(
            node: node,
            service: service,
            serviceType: serviceType
        )
    }
    
    private func handleMessage(topic: String, message: Any) {
        if let handler = messageHandlers[topic] {
            handler(message)
        }
    }
    
    private func convertToROSMessage(_ dict: [String: Any], for topic: String) throws -> Any {
        // Convert dictionary to appropriate ROS2 message type
        // This is a simplified implementation - in practice, you'd use proper ROS2 message serialization
        
        switch topic {
        case "/cmd_vel_user":
            return try convertToTwistMessage(dict)
        case "/servo_controller":
            return try convertToServoControlMessage(dict)
        default:
            return dict
        }
    }
    
    private func convertToTwistMessage(_ dict: [String: Any]) throws -> Any {
        // Convert to geometry_msgs/Twist
        guard let linear = dict["linear"] as? [String: Any],
              let angular = dict["angular"] as? [String: Any] else {
            throw ROS2Error.invalidMessageFormat
        }
        
        return Twist(
            linear: Twist.Vector3(
                x: linear["x"] as? Double ?? 0.0,
                y: linear["y"] as? Double ?? 0.0,
                z: linear["z"] as? Double ?? 0.0
            ),
            angular: Twist.Vector3(
                x: angular["x"] as? Double ?? 0.0,
                y: angular["y"] as? Double ?? 0.0,
                z: angular["z"] as? Double ?? 0.0
            )
        )
    }
    
    private func convertToServoControlMessage(_ dict: [String: Any]) throws -> Any {
        // Convert to servo control message
        guard let positions = dict["position"] as? [[String: Any]] else {
            throw ROS2Error.invalidMessageFormat
        }
        
        let servoPositions: [ServoControl.ServoPosition] = positions.compactMap { pos in
            guard let id = pos["id"] as? Int,
                  let position = pos["position"] as? Int else {
                return nil
            }
            return ServoControl.ServoPosition(id: id, position: position)
        }
        
        return ServoControl(
            duration: dict["duration"] as? Double ?? 0.1,
            positionUnit: dict["position_unit"] as? String ?? "pulse",
            position: servoPositions
        )
    }
    
    private func getMessageType(for topic: String) -> String {
        switch topic {
        case "/cmd_vel_user":
            return "geometry_msgs/Twist"
        case "/servo_controller":
            return "interfaces/ServoControl"
        case "/scan":
            return "sensor_msgs/LaserScan"
        case "/map":
            return "nav_msgs/OccupancyGrid"
        case "/cloud_map":
            return "sensor_msgs/PointCloud2"
        case "/obstacle_warning":
            return "std_msgs/Bool"
        case "/safety_override":
            return "std_msgs/Bool"
        case "/execute_action":
            return "std_msgs/String"
        default:
            return "std_msgs/String"
        }
    }
    
    private func getServiceType(for service: String) -> String {
        switch service {
        case "/list_available_actions":
            return "std_srvs/srv/Trigger"
        case "/slam_toolbox/clear_queue":
            return "std_srvs/srv/Trigger"
        default:
            return "std_srvs/srv/Trigger"
        }
    }
}

// MARK: - ROS2 Classes (Simplified Implementation)

class ROS2Context {
    let domainId: Int
    
    init(domainId: Int) throws {
        self.domainId = domainId
        // Initialize DDS context
        print("🔧 Initializing ROS2 context with domain ID: \(domainId)")
    }
}

class ROS2Node {
    let name: String
    let context: ROS2Context
    
    init(name: String, context: ROS2Context) throws {
        self.name = name
        self.context = context
        print("🔧 Created ROS2 node: \(name)")
    }
}

class ROS2Publisher {
    let node: ROS2Node
    let topic: String
    let messageType: String
    
    init(node: ROS2Node, topic: String, messageType: String) throws {
        self.node = node
        self.topic = topic
        self.messageType = messageType
        print("📤 Created publisher for \(topic) (\(messageType))")
    }
    
    func publish(_ message: Any) throws {
        // Publish message via DDS
        print("📤 Publishing to \(topic): \(message)")
    }
}

class ROS2Subscriber {
    let node: ROS2Node
    let topic: String
    let messageType: String
    let callback: (Any) -> Void
    
    init(node: ROS2Node, topic: String, messageType: String, callback: @escaping (Any) -> Void) throws {
        self.node = node
        self.topic = topic
        self.messageType = messageType
        self.callback = callback
        print("📥 Created subscriber for \(topic) (\(messageType))")
        
        // Start receiving messages
        startReceiving()
    }
    
    private func startReceiving() {
        // Start DDS subscription
        // In a real implementation, this would set up the DDS subscription
        print("📥 Started receiving messages from \(topic)")
    }
}

class ROS2ServiceClient {
    let node: ROS2Node
    let service: String
    let serviceType: String
    
    init(node: ROS2Node, service: String, serviceType: String) throws {
        self.node = node
        self.service = service
        self.serviceType = serviceType
        print("🔔 Created service client for \(service) (\(serviceType))")
    }
    
    func call(_ request: [String: Any]) async throws -> [String: Any] {
        // Call ROS2 service
        print("🔔 Calling service \(service) with request: \(request)")
        
        // Simulate service response
        return ["success": true, "message": "Service call successful"]
    }
}

// MARK: - Errors

enum ROS2Error: Error, LocalizedError {
    case nodeNotInitialized
    case invalidMessageFormat
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .nodeNotInitialized:
            return "ROS2 node not initialized"
        case .invalidMessageFormat:
            return "Invalid message format"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        }
    }
}

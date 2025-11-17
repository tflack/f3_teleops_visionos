//
//  ROS2WebSocketManager.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine
import Network

/// Manages WebSocket connection to ROS2 via rosbridge
@MainActor
public class ROS2WebSocketManager: ObservableObject {
    // Singleton instance
    public static let shared = ROS2WebSocketManager()
    
    @Published var isConnected = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?
    
    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var subscriptions: [String: String] = [:] // topic -> subscription ID
    private var messageHandlers: [String: (Any) -> Void] = [:]
    private var serviceCallHandlers: [String: (Result<[String: Any], Error>) -> Void] = [:]
    
    var serverIP: String
    private let serverPort: Int
    private let reconnectInterval: TimeInterval = 5.0
    private let heartbeatInterval: TimeInterval = 30.0
    
    // Private initializer to enforce singleton pattern
    private init(serverIP: String = "192.168.1.49", serverPort: Int = 9090) {
        self.serverIP = serverIP
        self.serverPort = serverPort
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        self.urlSession = URLSession(configuration: config)
        print("🤖 ROS2WebSocketManager singleton instance created: \(ObjectIdentifier(self)) for \(serverIP):\(serverPort)")
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.disconnect()
        }
    }
    
    // MARK: - Singleton Configuration
    
    /// Update the server IP address for the singleton instance
    func updateServerIP(_ newIP: String) {
        print("🤖 Updating server IP from \(serverIP) to \(newIP)")
        serverIP = newIP
    }
    
    // MARK: - Connection Management
    
    func connect() {
        guard case .disconnected = connectionState else { 
            print("🔌 WebSocket already connected or connecting, current state: \(connectionState)")
            return 
        }
        
        print("🔌 Starting WebSocket connection to \(serverIP):\(serverPort)")
        updateConnectionState(.connecting)
        lastError = nil
        
        // Test basic connectivity first
        testBasicConnectivity()
        
        let urlString = "ws://\(serverIP):\(serverPort)"
        guard let url = URL(string: urlString) else {
            let errorMsg = "Invalid URL: \(urlString)"
            print("❌ WebSocket connection failed: \(errorMsg)")
            updateConnectionState(.error(errorMsg))
            return
        }
        
        print("🔌 Creating WebSocket task for URL: \(urlString)")
        webSocketTask = urlSession.webSocketTask(with: url)
        
        // Add connection state monitoring
        webSocketTask?.resume()
        
        // Monitor connection state with more detailed timing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let self = self, case .connecting = self.connectionState {
                print("🔌 WebSocket connection still in progress after 0.5 seconds")
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if let self = self, case .connecting = self.connectionState {
                print("🔌 WebSocket connection still in progress after 1 second")
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if let self = self, case .connecting = self.connectionState {
                print("🔌 WebSocket connection still in progress after 2 seconds - this may indicate a connection issue")
                // Force a connection test
                self.testWebSocketConnection()
            }
        }
        
        startReceiving()
        startHeartbeat()
        
        print("🔌 WebSocket connection initiated to \(urlString)")
    }
    
    func disconnect() {
        stopHeartbeat()
        stopReconnect()
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        updateConnectionState(.disconnected)
        subscriptions.removeAll()
        
        print("🔌 Disconnected from ROS2 WebSocket")
    }
    
    private func startReceiving() {
        print("🔌 Starting to receive WebSocket messages...")
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handleReceiveResult(result)
            }
        }
    }
    
    private func handleReceiveResult(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            print("📨 WebSocket message received successfully")
            
            // If we were in connecting state and received a message, we're now connected
            if case .connecting = connectionState {
                print("✅ First message received - WebSocket connection established!")
                updateConnectionState(.connected)
            }
            
            handleMessage(message)
            startReceiving() // Continue receiving
        case .failure(let error):
            print("❌ WebSocket receive error: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            handleConnectionError(error)
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleTextMessage(text)
        case .data(let data):
            handleDataMessage(data)
        @unknown default:
            print("⚠️ Unknown WebSocket message type")
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            handleJSONMessage(json)
        } catch {
            print("❌ Failed to parse WebSocket message: \(error)")
        }
    }
    
    private func handleDataMessage(_ data: Data) {
        // Handle binary data if needed
        print("📦 Received binary data: \(data.count) bytes")
    }
    
    private func handleJSONMessage(_ json: [String: Any]?) {
        guard let json = json else { return }
        
        // If we received any message and were in connecting state, we're now connected
        if case .connecting = connectionState {
            print("✅ Received message from rosbridge - connection established!")
            updateConnectionState(.connected)
        }
        
        // Handle different message types
        if let op = json["op"] as? String {
            switch op {
            case "publish":
                handlePublishMessage(json)
            case "service_response":
                handleServiceResponse(json)
            case "status":
                handleStatusMessage(json)
            default:
                print("📨 Unknown message op: \(op)")
            }
        }
    }
    
    private func handlePublishMessage(_ json: [String: Any]) {
        guard let topic = json["topic"] as? String,
              let msg = json["msg"] else { return }
        
        // Call registered handler for this topic
        if let handler = messageHandlers[topic] {
            handler(msg)
        }
    }
    
    private func handleServiceResponse(_ json: [String: Any]) {
        // Get the service call ID
        guard let serviceId = json["id"] as? String else {
            print("🔔 Service response without ID: \(json)")
            return
        }
        
        // Check if we have a completion handler for this service call
        guard let completion = serviceCallHandlers[serviceId] else {
            print("🔔 Service response for unknown ID: \(serviceId)")
            return
        }
        
        // Remove the handler
        serviceCallHandlers.removeValue(forKey: serviceId)
        
        // Check if we have values in the response
        if let values = json["values"] as? [String: Any] {
            print("✅ Service response received for ID: \(serviceId)")
            completion(.success(values))
        } else if let result = json["result"] as? Bool, result == false {
            let errorMsg = json["error"] as? String ?? "Service call failed"
            print("❌ Service call failed: \(errorMsg)")
            completion(.failure(NSError(domain: "ROS2Service", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
        } else {
            // Return the entire json if no specific values field
            completion(.success(json))
        }
    }
    
    private func handleStatusMessage(_ json: [String: Any]) {
        // Handle status messages
        print("📊 Status: \(json)")
    }
    
    private func handleConnectionError(_ error: Error) {
        lastError = error.localizedDescription
        updateConnectionState(.error(error.localizedDescription))
        
        print("❌ WebSocket connection error: \(error.localizedDescription)")
        print("❌ Connection state changed to: \(connectionState)")
        print("❌ Is connected: \(isConnected)")
        
        // Attempt to reconnect
        scheduleReconnect()
    }
    
    private func scheduleReconnect() {
        stopReconnect()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: reconnectInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.connect()
            }
        }
    }
    
    private func stopReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func startHeartbeat() {
        stopHeartbeat()
        print("💓 Starting WebSocket heartbeat with \(heartbeatInterval) second interval")
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendHeartbeat()
            }
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() {
        print("💓 Sending WebSocket protocol ping")
        // Use WebSocket's built-in ping instead of custom message
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                print("❌ WebSocket ping failed: \(error.localizedDescription)")
                Task { @MainActor [weak self] in
                    self?.handleConnectionError(error)
                }
            } else {
                print("✅ WebSocket ping successful")
            }
        }
    }
    
    // MARK: - Message Sending
    
    private func sendMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("❌ Failed to serialize message: \(message)")
            return
        }
        
        print("📤 Sending WebSocket message: \(jsonString)")
        
        webSocketTask?.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                print("❌ Failed to send message: \(error.localizedDescription)")
                Task { @MainActor [weak self] in
                    self?.handleConnectionError(error)
                }
            } else {
                print("✅ Message sent successfully")
            }
        }
    }
    
    // MARK: - Topic Management
    
    func subscribe(to topic: String, messageType: String, handler: @escaping (Any) -> Void) {
        let subscriptionId = "\(topic)_\(UUID().uuidString)"
        
        let message: [String: Any] = [
            "op": "subscribe",
            "id": subscriptionId,
            "topic": topic,
            "type": messageType
        ]
        
        subscriptions[topic] = subscriptionId
        messageHandlers[topic] = handler
        
        // Only send subscription if connected, otherwise it will be queued
        // and sent when connection is established
        if case .connected = connectionState {
            sendMessage(message)
        } else {
            // Try to send anyway - rosbridge might queue it
            sendMessage(message)
        }
    }
    
    func unsubscribe(from topic: String) {
        guard let subscriptionId = subscriptions[topic] else { return }
        
        let message = [
            "op": "unsubscribe",
            "id": subscriptionId,
            "topic": topic
        ]
        
        subscriptions.removeValue(forKey: topic)
        messageHandlers.removeValue(forKey: topic)
        
        sendMessage(message)
        print("📡 Unsubscribed from \(topic)")
    }
    
    func publish(to topic: String, message: [String: Any]) {
        let publishMessage: [String: Any] = [
            "op": "publish",
            "topic": topic,
            "msg": message
        ]
        
        sendMessage(publishMessage)
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
    
    func callService(service: String, serviceType: String = "std_srvs/srv/Trigger", request: [String: Any] = [:], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let serviceId = "service_\(UUID().uuidString)"
        
        let message: [String: Any] = [
            "op": "call_service",
            "id": serviceId,
            "service": service,
            "type": serviceType,
            "args": request
        ]
        
        // Store completion handler for this service call
        serviceCallHandlers[serviceId] = completion
        
        sendMessage(message)
        print("🔔 Called service \(service) with ID: \(serviceId)")
    }
    
    // MARK: - Connection Testing
    
    private func testBasicConnectivity() {
        print("🔍 Testing basic connectivity to \(serverIP):\(serverPort)")
        
        // Use a simple TCP connection test
        let connection = NWConnection(
            host: NWEndpoint.Host(serverIP),
            port: NWEndpoint.Port(integerLiteral: UInt16(serverPort)),
            using: .tcp
        )
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Basic TCP connectivity test passed - server is reachable")
                connection.cancel()
            case .failed(let error):
                print("❌ Basic TCP connectivity test failed: \(error.localizedDescription)")
                connection.cancel()
            case .cancelled:
                print("🔍 Basic TCP connectivity test cancelled")
            default:
                break
            }
        }
        
        connection.start(queue: DispatchQueue.global())
        
        // Timeout after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            connection.cancel()
        }
    }
    
    private func testWebSocketConnection() {
        print("🔍 Testing WebSocket connection with rosbridge protocol...")
        
        // Try to get the list of topics to test rosbridge connectivity
        let message: [String: Any] = [
            "op": "call_service",
            "service": "/rosapi/topics",
            "args": []
        ]
        
        print("📤 Sending rosbridge service call to test connection...")
        sendMessage(message)
        
        // Also try a WebSocket protocol ping
        webSocketTask?.sendPing { [weak self] error in
            Task { @MainActor [weak self] in
                if let error = error {
                    print("❌ WebSocket protocol ping failed: \(error.localizedDescription)")
                } else {
                    print("✅ WebSocket protocol ping successful")
                }
            }
        }
    }
    
    // MARK: - Connection State Updates
    
    private func updateConnectionState(_ state: ConnectionState) {
        let previousState = connectionState
        connectionState = state
        
        print("🔄 WebSocket connection state changed: \(previousState) -> \(state)")
        
        switch state {
        case .connected:
            isConnected = true
            print("✅ WebSocket connected successfully to \(serverIP):\(serverPort)")
            // Resubscribe to all topics when connection is established
            resubscribeToAllTopics()
        case .connecting:
            isConnected = false
            print("🔄 WebSocket connecting to \(serverIP):\(serverPort)")
        case .disconnected:
            isConnected = false
            print("🔌 WebSocket disconnected from \(serverIP):\(serverPort)")
        case .error(let message):
            isConnected = false
            print("❌ WebSocket error: \(message)")
        }
    }
    
    private func resubscribeToAllTopics() {
        print("🔄 Resubscribing to all topics after connection...")
        // Get all current subscriptions and resubscribe
        let topicsToResubscribe = Array(subscriptions.keys)
        for topic in topicsToResubscribe {
            if let handler = messageHandlers[topic] {
                // Get the message type - we'll need to store this
                // For now, we'll just log that we need to resubscribe
                print("🔄 Need to resubscribe to \(topic) - handler exists")
            }
        }
        // Note: The actual resubscription will happen when setupSLAMSubscriptions is called
        // from the view's onChange handler
    }
}

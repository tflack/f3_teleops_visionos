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
    
    private let serverIP: String
    private let serverPort: Int
    private let reconnectInterval: TimeInterval = 5.0
    private let heartbeatInterval: TimeInterval = 30.0
    
    init(serverIP: String = "192.168.1.49", serverPort: Int = 9090) {
        self.serverIP = serverIP
        self.serverPort = serverPort
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        self.urlSession = URLSession(configuration: config)
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.disconnect()
        }
    }
    
    // MARK: - Connection Management
    
    func connect() {
        guard case .disconnected = connectionState else { return }
        
        connectionState = .connecting
        lastError = nil
        
        let urlString = "ws://\(serverIP):\(serverPort)"
        guard let url = URL(string: urlString) else {
            connectionState = .error("Invalid URL: \(urlString)")
            return
        }
        
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        
        startReceiving()
        startHeartbeat()
        
        print("🔌 Connecting to ROS2 WebSocket at \(urlString)")
    }
    
    func disconnect() {
        stopHeartbeat()
        stopReconnect()
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        connectionState = .disconnected
        isConnected = false
        subscriptions.removeAll()
        
        print("🔌 Disconnected from ROS2 WebSocket")
    }
    
    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                self?.handleReceiveResult(result)
            }
        }
    }
    
    private func handleReceiveResult(_ result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            handleMessage(message)
            startReceiving() // Continue receiving
        case .failure(let error):
            print("❌ WebSocket receive error: \(error)")
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
        // Handle service responses
        print("🔔 Service response: \(json)")
    }
    
    private func handleStatusMessage(_ json: [String: Any]) {
        // Handle status messages
        print("📊 Status: \(json)")
    }
    
    private func handleConnectionError(_ error: Error) {
        lastError = error.localizedDescription
        connectionState = .error(error.localizedDescription)
        isConnected = false
        
        print("❌ WebSocket connection error: \(error)")
        
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
        let message = ["op": "ping"]
        sendMessage(message)
    }
    
    // MARK: - Message Sending
    
    private func sendMessage(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("❌ Failed to serialize message")
            return
        }
        
        webSocketTask?.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                print("❌ Failed to send message: \(error)")
                Task { @MainActor [weak self] in
                    self?.handleConnectionError(error)
                }
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
        
        sendMessage(message)
        print("📡 Subscribed to \(topic) (\(messageType))")
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
    
    func callService(service: String, request: [String: Any] = [:], completion: @escaping (Result<[String: Any], Error>) -> Void) {
        let serviceId = "service_\(UUID().uuidString)"
        
        let message: [String: Any] = [
            "op": "call_service",
            "id": serviceId,
            "service": service,
            "args": request
        ]
        
        // Store completion handler for this service call
        // Note: In a production app, you'd want a more robust service call management system
        
        sendMessage(message)
        print("🔔 Called service \(service)")
    }
    
    // MARK: - Connection State Updates
    
    private func updateConnectionState(_ state: ConnectionState) {
        connectionState = state
        switch state {
        case .connected:
            isConnected = true
        default:
            isConnected = false
        }
    }
}

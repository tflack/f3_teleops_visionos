import Foundation

class SimpleTopicTest {
    private var debugMessages: [String] = []
    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 30.0
        self.urlSession = URLSession(configuration: config)
    }
    
    func runTest() {
        print("🔍 Starting Simple Topic Test")
        print(String(repeating: "=", count: 50))
        
        let serverIP = "192.168.1.49"
        let serverPort = 9090
        
        // Connect to ROS2 WebSocket server
        connectToROS2(serverIP: serverIP, serverPort: serverPort)
        
        // Keep the test running for 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.printResults()
            self.disconnect()
            exit(0)
        }
        
        // Keep the main thread alive
        RunLoop.main.run()
    }
    
    private func connectToROS2(serverIP: String, serverPort: Int) {
        addDebugMessage("🔌 Connecting to ROS2 WebSocket server at \(serverIP):\(serverPort)")
        
        let urlString = "ws://\(serverIP):\(serverPort)"
        guard let url = URL(string: urlString) else {
            addDebugMessage("❌ Invalid WebSocket URL: \(urlString)")
            return
        }
        
        addDebugMessage("🔌 Creating WebSocket connection to: \(urlString)")
        webSocket = urlSession.webSocketTask(with: url)
        
        webSocket?.resume()
        startReceiving()
        
        // Try to subscribe to topics that we know work in F3 Teleops
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.testKnownTopics()
        }
    }
    
    private func startReceiving() {
        webSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self?.startReceiving()
            case .failure(let error):
                self?.addDebugMessage("❌ WebSocket receive error: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleMessage(_ message: String) {
        addDebugMessage("📨 Received: \(message)")
        
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            addDebugMessage("❌ Failed to parse message as JSON")
            return
        }
        
        if let topic = json["topic"] as? String {
            addDebugMessage("✅ Received data for topic: \(topic)")
        }
        
        if let op = json["op"] as? String {
            addDebugMessage("📋 Operation: \(op)")
        }
    }
    
    private func testKnownTopics() {
        let topics = [
            ("/obstacle_warning", "std_msgs/Bool"),
            ("/detected_objects", "interfaces/DetectedObjects"),
            ("/map", "nav_msgs/OccupancyGrid"),
            ("/cloud_map", "sensor_msgs/PointCloud2"),
            ("/tf", "tf2_msgs/TFMessage")
        ]
        
        for (topic, messageType) in topics {
            subscribeToTopic(topic, messageType: messageType)
        }
    }
    
    private func subscribeToTopic(_ topic: String, messageType: String) {
        addDebugMessage("📡 Subscribing to \(topic) (\(messageType))")
        
        let message = [
            "op": "subscribe",
            "id": "\(topic)_\(Date().timeIntervalSince1970)",
            "topic": topic,
            "type": messageType
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: message),
              let jsonString = String(data: data, encoding: .utf8) else {
            addDebugMessage("❌ Failed to create subscription message for \(topic)")
            return
        }
        
        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                self?.addDebugMessage("❌ Failed to subscribe to \(topic): \(error.localizedDescription)")
            } else {
                self?.addDebugMessage("✅ Subscription sent for \(topic)")
            }
        }
    }
    
    private func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }
    
    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let fullMessage = "[\(timestamp)] \(message)"
        debugMessages.append(fullMessage)
        print(fullMessage)
    }
    
    private func printResults() {
        print("\n" + String(repeating: "=", count: 50))
        print("🔍 Simple Topic Test Results")
        print(String(repeating: "=", count: 50))
        
        let totalMessages = debugMessages.count
        let receivedData = debugMessages.filter { $0.contains("Received data for topic") }.count
        let subscriptions = debugMessages.filter { $0.contains("Subscription sent") }.count
        
        print("📊 Total messages: \(totalMessages)")
        print("📡 Subscriptions sent: \(subscriptions)")
        print("📨 Data messages received: \(receivedData)")
        
        if receivedData > 0 {
            print("\n✅ Topics with data:")
            debugMessages.filter { $0.contains("Received data for topic") }.forEach { print("  \($0)") }
        } else {
            print("\n❌ No data received from any topics")
        }
        
        print("\n📋 Full Debug Log:")
        debugMessages.forEach { print($0) }
    }
}

// Run the test
let test = SimpleTopicTest()
test.runTest()

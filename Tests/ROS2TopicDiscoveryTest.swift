import Foundation

class ROS2TopicDiscoveryTest {
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
        print("🔍 Starting ROS2 Topic Discovery Test")
        print(String(repeating: "=", count: 50))
        
        let serverIP = "192.168.1.49"
        let serverPort = 9090
        
        // Connect to ROS2 WebSocket server
        connectToROS2(serverIP: serverIP, serverPort: serverPort)
        
        // Keep the test running for 15 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
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
        
        // Request topic list after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestTopicList()
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
        addDebugMessage("📨 Received message: \(message)")
        
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            addDebugMessage("❌ Failed to parse message as JSON")
            return
        }
        
        if let op = json["op"] as? String {
            switch op {
            case "publish":
                addDebugMessage("📤 Publish message received")
            case "subscribe":
                addDebugMessage("📡 Subscribe message received")
            case "unsubscribe":
                addDebugMessage("📡 Unsubscribe message received")
            case "call_service":
                addDebugMessage("🔧 Service call message received")
            case "advertise":
                addDebugMessage("📢 Advertise message received")
            case "unadvertise":
                addDebugMessage("📢 Unadvertise message received")
            case "topics":
                handleTopicList(json)
            case "services":
                addDebugMessage("🔧 Services list received")
            case "status":
                addDebugMessage("📊 Status message received")
            default:
                addDebugMessage("❓ Unknown message type: \(op)")
            }
        }
    }
    
    private func handleTopicList(_ json: [String: Any]) {
        addDebugMessage("📋 Topic list received!")
        
        if let topics = json["topics"] as? [String] {
            addDebugMessage("🎉 Found \(topics.count) available topics:")
            for (index, topic) in topics.enumerated() {
                addDebugMessage("  \(index + 1). \(topic)")
            }
            
            // Test some common topics
            testCommonTopics(topics)
        } else {
            addDebugMessage("❌ No topics found in response")
        }
    }
    
    private func testCommonTopics(_ topics: [String]) {
        let commonTopics = ["/map", "/tf", "/cloud_map", "/scan", "/odom", "/imu", "/cmd_vel"]
        
        for topic in commonTopics {
            if topics.contains(topic) {
                addDebugMessage("✅ Found common topic: \(topic)")
            } else {
                addDebugMessage("❌ Missing common topic: \(topic)")
            }
        }
    }
    
    private func requestTopicList() {
        addDebugMessage("📋 Requesting topic list from ROS2 server...")
        
        let request = [
            "op": "get_topics"
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: request),
              let jsonString = String(data: data, encoding: .utf8) else {
            addDebugMessage("❌ Failed to create topic list request")
            return
        }
        
        webSocket?.send(.string(jsonString)) { [weak self] error in
            if let error = error {
                self?.addDebugMessage("❌ Failed to send topic list request: \(error.localizedDescription)")
            } else {
                self?.addDebugMessage("✅ Topic list request sent")
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
        print("🔍 ROS2 Topic Discovery Test Results")
        print(String(repeating: "=", count: 50))
        
        let totalMessages = debugMessages.count
        let topicMessages = debugMessages.filter { $0.contains("Found") && $0.contains("topics") }.count
        let commonTopicMessages = debugMessages.filter { $0.contains("Found common topic") }.count
        
        print("📊 Total messages: \(totalMessages)")
        print("📋 Topic list responses: \(topicMessages)")
        print("✅ Common topics found: \(commonTopicMessages)")
        
        if commonTopicMessages > 0 {
            print("\n✅ Common topics found:")
            debugMessages.filter { $0.contains("Found common topic") }.forEach { print("  \($0)") }
        }
        
        print("\n📋 Full Debug Log:")
        debugMessages.forEach { print($0) }
    }
}

// Run the test
let test = ROS2TopicDiscoveryTest()
test.runTest()

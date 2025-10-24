import Foundation

class TopicDiscoveryTest {
    private var debugMessages: [String] = []
    
    func runTest() {
        print("🔍 Starting Topic Discovery Test")
        print(String(repeating: "=", count: 50))
        
        let baseURL = "http://192.168.1.49:8080"
        
        // Get the topic list from the server
        discoverTopics(baseURL: baseURL)
        
        // Keep the test running for 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.printResults()
            exit(0)
        }
        
        // Keep the main thread alive
        RunLoop.main.run()
    }
    
    private func discoverTopics(baseURL: String) {
        addDebugMessage("🔍 Discovering available topics from \(baseURL)")
        
        guard let url = URL(string: baseURL) else {
            addDebugMessage("❌ Invalid base URL: \(baseURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.addDebugMessage("❌ Topic discovery error: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addDebugMessage("✅ Topic discovery response: \(httpResponse.statusCode)")
            }
            
            if let data = data, let htmlString = String(data: data, encoding: .utf8) {
                self.addDebugMessage("✅ Received \(data.count) bytes of HTML")
                self.parseTopicsFromHTML(htmlString, baseURL: baseURL)
            }
        }
        
        task.resume()
        addDebugMessage("🔍 Topic discovery task started")
    }
    
    private func parseTopicsFromHTML(_ html: String, baseURL: String) {
        addDebugMessage("🔍 Parsing topics from HTML response")
        
        // Look for topic links in the HTML
        let lines = html.components(separatedBy: .newlines)
        var foundTopics: [String] = []
        
        for line in lines {
            if line.contains("href=\"/stream_viewer?topic=") {
                // Extract topic name from href
                if let startRange = line.range(of: "topic="),
                   let endRange = line.range(of: "\"", range: startRange.upperBound..<line.endIndex) {
                    let topicName = String(line[startRange.upperBound..<endRange.lowerBound])
                    foundTopics.append(topicName)
                }
            }
        }
        
        addDebugMessage("🎉 Found \(foundTopics.count) available topics:")
        for (index, topic) in foundTopics.enumerated() {
            addDebugMessage("  \(index + 1). \(topic)")
        }
        
        // Test each discovered topic
        for (index, topic) in foundTopics.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.0) {
                self.testTopic("\(baseURL)/stream?topic=\(topic)", topicName: topic)
            }
        }
    }
    
    private func testTopic(_ urlString: String, topicName: String) {
        addDebugMessage("🔍 Testing topic: \(topicName)")
        
        guard let url = URL(string: urlString) else {
            addDebugMessage("❌ Invalid topic URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.addDebugMessage("❌ Topic '\(topicName)' error: \(error._code)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addDebugMessage("✅ Topic '\(topicName)' response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
                    self.addDebugMessage("🎉 Topic '\(topicName)' is working! Content-Type: \(contentType)")
                    
                    if let data = data {
                        self.addDebugMessage("✅ Topic '\(topicName)' received \(data.count) bytes")
                        let firstBytes = data.prefix(10)
                        self.addDebugMessage("✅ Topic '\(topicName)' first 10 bytes: \(firstBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
                        
                        // Check if it's JPEG data
                        if firstBytes.count >= 2 && firstBytes[0] == 0xFF && firstBytes[1] == 0xD8 {
                            self.addDebugMessage("🎉 Topic '\(topicName)' contains valid JPEG data!")
                        }
                    }
                }
            }
        }
        
        task.resume()
    }
    
    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let fullMessage = "[\(timestamp)] \(message)"
        debugMessages.append(fullMessage)
        print(fullMessage)
    }
    
    private func printResults() {
        print("\n" + String(repeating: "=", count: 50))
        print("🔍 Topic Discovery Test Results")
        print(String(repeating: "=", count: 50))
        
        let totalMessages = debugMessages.count
        let workingTopics = debugMessages.filter { $0.contains("🎉 Topic") && $0.contains("is working") }.count
        let jpegTopics = debugMessages.filter { $0.contains("contains valid JPEG data") }.count
        
        print("📊 Total messages: \(totalMessages)")
        print("🎉 Working topics found: \(workingTopics)")
        print("📸 Topics with JPEG data: \(jpegTopics)")
        
        if jpegTopics > 0 {
            print("\n📸 Topics with JPEG data:")
            debugMessages.filter { $0.contains("contains valid JPEG data") }.forEach { print("  \($0)") }
        }
        
        print("\n📋 Full Debug Log:")
        debugMessages.forEach { print($0) }
    }
}

// Run the test
let test = TopicDiscoveryTest()
test.runTest()

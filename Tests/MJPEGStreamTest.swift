import Foundation

class MJPEGStreamTest {
    private var dataTask: URLSessionDataTask?
    private var receivedData = Data()
    private var debugMessages: [String] = []
    
    func runTest() {
        print("🧪 Starting MJPEG Stream Test")
        print(String(repeating: "=", count: 50))
        
        let testURL = "http://192.168.1.49:8080/stream?topic=/depth_cam/depth/image_raw"
        
        guard let url = URL(string: testURL) else {
            addDebugMessage("❌ Invalid URL: \(testURL)")
            return
        }
        
        addDebugMessage("📹 Starting MJPEG stream from: \(url.absoluteString)")
        receivedData = Data()
        
        // Create a simple HTTP request to get the MJPEG stream
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        request.setValue("close", forHTTPHeaderField: "Connection")
        
        addDebugMessage("📹 Making HTTP request to MJPEG stream...")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            self.addDebugMessage("📹 URLSession completion handler called")
            
            if let error = error {
                self.addDebugMessage("📹 MJPEG stream error: \(error)")
                self.addDebugMessage("📹 Error code: \(error._code)")
                self.addDebugMessage("📹 Error domain: \(error._domain)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addDebugMessage("📹 MJPEG HTTP response: \(httpResponse.statusCode)")
                self.addDebugMessage("📹 MJPEG Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
                self.addDebugMessage("📹 MJPEG Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "unknown")")
                
                if httpResponse.statusCode != 200 {
                    self.addDebugMessage("📹 MJPEG HTTP error: \(httpResponse.statusCode)")
                    return
                }
            }
            
            if let data = data {
                self.addDebugMessage("📹 MJPEG received \(data.count) bytes")
                // Log first few bytes to see what we're getting
                let firstBytes = data.prefix(20)
                self.addDebugMessage("📹 MJPEG first 20 bytes: \(firstBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
                self.parseMJPEGData(data)
            } else {
                self.addDebugMessage("📹 MJPEG received no data")
            }
        }
        
        dataTask = task
        task.resume()
        addDebugMessage("📹 URLSession task started")
        
        // Set a timeout to try a different approach if this doesn't work
        addDebugMessage("📹 Setting 5-second timeout for MJPEG stream...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.addDebugMessage("📹 Timeout check: checking if we should try alternative approach")
            self.tryAlternativeMJPEGApproach(url: url)
        }
        
        // Also try a simple test request to see if we can get any response
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.addDebugMessage("📹 2-second timer fired - testing simple HTTP request")
            self.testSimpleHTTPRequest(url: url)
        }
        
        // Keep the test running for 10 seconds to see all results
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            self.printResults()
            exit(0)
        }
        
        // Keep the main thread alive
        RunLoop.main.run()
    }
    
    private func tryAlternativeMJPEGApproach(url: URL) {
        addDebugMessage("📹 Trying alternative MJPEG approach...")
        
        // Cancel the current task
        dataTask?.cancel()
        
        // Try using a different approach - get just enough data for one frame
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        request.setValue("bytes=0-50000", forHTTPHeaderField: "Range") // Try to get first 50KB
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            self.addDebugMessage("📹 Alternative MJPEG approach completion handler called")
            
            if let error = error {
                self.addDebugMessage("📹 Alternative MJPEG stream error: \(error)")
                self.addDebugMessage("📹 Alternative MJPEG error code: \(error._code)")
                self.addDebugMessage("📹 Alternative MJPEG error domain: \(error._domain)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addDebugMessage("📹 Alternative MJPEG HTTP response: \(httpResponse.statusCode)")
                self.addDebugMessage("📹 Alternative MJPEG Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
                self.addDebugMessage("📹 Alternative MJPEG Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "unknown")")
            }
            
            if let data = data {
                self.addDebugMessage("📹 Alternative MJPEG received \(data.count) bytes")
                // Log first few bytes to see what we're getting
                let firstBytes = data.prefix(20)
                self.addDebugMessage("📹 Alternative MJPEG first 20 bytes: \(firstBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
                self.parseMJPEGData(data)
            } else {
                self.addDebugMessage("📹 Alternative MJPEG received no data")
            }
        }
        
        dataTask = task
        task.resume()
        addDebugMessage("📹 Alternative MJPEG URLSession task started")
    }
    
    private func testSimpleHTTPRequest(url: URL) {
        addDebugMessage("📹 Testing simple HTTP request...")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        request.setValue("text/plain", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            self.addDebugMessage("📹 Simple HTTP test completion handler called")
            
            if let error = error {
                self.addDebugMessage("📹 Simple HTTP test error: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addDebugMessage("📹 Simple HTTP test response: \(httpResponse.statusCode)")
                self.addDebugMessage("📹 Simple HTTP test Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
            }
            
            if let data = data {
                self.addDebugMessage("📹 Simple HTTP test received \(data.count) bytes")
                // Just log the first few bytes to see what we're getting
                let firstBytes = data.prefix(100)
                self.addDebugMessage("📹 Simple HTTP test first 100 bytes: \(firstBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
            } else {
                self.addDebugMessage("📹 Simple HTTP test received no data")
            }
        }
        
        task.resume()
        addDebugMessage("📹 Simple HTTP test task started")
    }
    
    private func parseMJPEGData(_ data: Data) {
        // Check if data starts with JPEG markers
        let bytes = Array(data.prefix(4))
        if bytes.count >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8 {
            addDebugMessage("✅ Data appears to be valid JPEG (starts with FF D8)")
            addDebugMessage("✅ JPEG data size: \(data.count) bytes")
        } else {
            addDebugMessage("❌ Data does not appear to be valid JPEG")
            addDebugMessage("❌ First 4 bytes: \(bytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
            
            // Try to find JPEG data within the multipart stream
            if let jpegData = extractJPEGFromMultipart(data) {
                addDebugMessage("✅ Found JPEG data within multipart stream")
                addDebugMessage("✅ Extracted JPEG size: \(jpegData.count) bytes")
            } else {
                addDebugMessage("❌ No JPEG data found in multipart stream")
            }
        }
    }
    
    private func extractJPEGFromMultipart(_ data: Data) -> Data? {
        // Look for JPEG start marker (0xFF 0xD8) and end marker (0xFF 0xD9)
        let jpegStart: [UInt8] = [0xFF, 0xD8]
        let jpegEnd: [UInt8] = [0xFF, 0xD9]
        
        let bytes = Array(data)
        
        // Find start marker
        guard let startIndex = bytes.firstIndex(of: jpegStart[0]) else { return nil }
        guard startIndex + 1 < bytes.count && bytes[startIndex + 1] == jpegStart[1] else { return nil }
        
        // Find end marker
        var endIndex = startIndex + 2
        while endIndex + 1 < bytes.count {
            if bytes[endIndex] == jpegEnd[0] && bytes[endIndex + 1] == jpegEnd[1] {
                let jpegData = Data(bytes[startIndex...endIndex + 1])
                addDebugMessage("📹 Extracted JPEG data: \(jpegData.count) bytes")
                return jpegData
            }
            endIndex += 1
        }
        
        return nil
    }
    
    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let fullMessage = "[\(timestamp)] \(message)"
        debugMessages.append(fullMessage)
        print(fullMessage)
    }
    
    private func printResults() {
        print("\n" + String(repeating: "=", count: 50))
        print("🧪 MJPEG Stream Test Results")
        print(String(repeating: "=", count: 50))
        
        let totalMessages = debugMessages.count
        let errorMessages = debugMessages.filter { $0.contains("❌") || $0.contains("error") }.count
        let successMessages = debugMessages.filter { $0.contains("✅") }.count
        
        print("📊 Total debug messages: \(totalMessages)")
        print("❌ Error messages: \(errorMessages)")
        print("✅ Success messages: \(successMessages)")
        
        if errorMessages > 0 {
            print("\n🔍 Error Summary:")
            debugMessages.filter { $0.contains("❌") || $0.contains("error") }.forEach { print("  \($0)") }
        }
        
        if successMessages > 0 {
            print("\n🎉 Success Summary:")
            debugMessages.filter { $0.contains("✅") }.forEach { print("  \($0)") }
        }
        
        print("\n📋 Full Debug Log:")
        debugMessages.forEach { print($0) }
    }
}

// Run the test
let test = MJPEGStreamTest()
test.runTest()

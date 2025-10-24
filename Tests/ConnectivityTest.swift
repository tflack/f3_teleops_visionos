import Foundation

class ConnectivityTest {
    private var debugMessages: [String] = []
    
    func runTest() {
        print("🌐 Starting Connectivity Test")
        print(String(repeating: "=", count: 50))
        
        let baseURL = "http://192.168.1.49:8080"
        let mjpegURL = "\(baseURL)/stream?topic=/depth_cam/rgb/image_raw"
        
        // Test 1: Basic server connectivity
        testBasicConnectivity(baseURL: baseURL)
        
        // Test 2: MJPEG endpoint
        testMJPEGEndpoint(url: mjpegURL)
        
        // Test 3: Different MJPEG parameters
        testAlternativeMJPEGParameters(baseURL: baseURL)
        
        // Keep the test running for 15 seconds to see all results
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
            self.printResults()
            exit(0)
        }
        
        // Keep the main thread alive
        RunLoop.main.run()
    }
    
    private func testBasicConnectivity(baseURL: String) {
        addDebugMessage("🔍 Test 1: Basic server connectivity to \(baseURL)")
        
        guard let url = URL(string: baseURL) else {
            addDebugMessage("❌ Invalid base URL: \(baseURL)")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            self.addDebugMessage("🔍 Basic connectivity completion handler called")
            
            if let error = error {
                self.addDebugMessage("❌ Basic connectivity error: \(error)")
                self.addDebugMessage("❌ Error code: \(error._code)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addDebugMessage("✅ Basic connectivity response: \(httpResponse.statusCode)")
                self.addDebugMessage("✅ Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
                self.addDebugMessage("✅ Server: \(httpResponse.value(forHTTPHeaderField: "Server") ?? "unknown")")
            }
            
            if let data = data {
                self.addDebugMessage("✅ Received \(data.count) bytes from server")
                if let responseString = String(data: data, encoding: .utf8) {
                    self.addDebugMessage("✅ Response preview: \(String(responseString.prefix(200)))")
                }
            }
        }
        
        task.resume()
        addDebugMessage("🔍 Basic connectivity task started")
    }
    
    private func testMJPEGEndpoint(url: String) {
        addDebugMessage("🔍 Test 2: MJPEG endpoint at \(url)")
        
        guard let url = URL(string: url) else {
            addDebugMessage("❌ Invalid MJPEG URL: \(url)")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.httpMethod = "GET"
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            self.addDebugMessage("🔍 MJPEG endpoint completion handler called")
            
            if let error = error {
                self.addDebugMessage("❌ MJPEG endpoint error: \(error)")
                self.addDebugMessage("❌ Error code: \(error._code)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addDebugMessage("✅ MJPEG endpoint response: \(httpResponse.statusCode)")
                self.addDebugMessage("✅ Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
                self.addDebugMessage("✅ Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "unknown")")
            }
            
            if let data = data {
                self.addDebugMessage("✅ MJPEG received \(data.count) bytes")
                let firstBytes = data.prefix(10)
                self.addDebugMessage("✅ First 10 bytes: \(firstBytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
            }
        }
        
        task.resume()
        addDebugMessage("🔍 MJPEG endpoint task started")
    }
    
    private func testAlternativeMJPEGParameters(baseURL: String) {
        addDebugMessage("🔍 Test 3: Alternative MJPEG parameters")
        
        let alternatives = [
            "\(baseURL)/stream?topic=/camera/rgb/image_raw",
            "\(baseURL)/stream?topic=/camera/image_raw",
            "\(baseURL)/stream?topic=/image_raw",
            "\(baseURL)/stream",
            "\(baseURL)/mjpeg",
            "\(baseURL)/video"
        ]
        
        for (index, altURL) in alternatives.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 2.0) {
                self.testAlternativeURL(altURL, index: index + 1)
            }
        }
    }
    
    private func testAlternativeURL(_ urlString: String, index: Int) {
        addDebugMessage("🔍 Test 3.\(index): Testing \(urlString)")
        
        guard let url = URL(string: urlString) else {
            addDebugMessage("❌ Invalid alternative URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                self.addDebugMessage("❌ Alternative \(index) error: \(error._code)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                self.addDebugMessage("✅ Alternative \(index) response: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    self.addDebugMessage("🎉 Found working endpoint: \(urlString)")
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
        print("🌐 Connectivity Test Results")
        print(String(repeating: "=", count: 50))
        
        let totalMessages = debugMessages.count
        let errorMessages = debugMessages.filter { $0.contains("❌") }.count
        let successMessages = debugMessages.filter { $0.contains("✅") }.count
        let workingEndpoints = debugMessages.filter { $0.contains("🎉") }.count
        
        print("📊 Total messages: \(totalMessages)")
        print("❌ Error messages: \(errorMessages)")
        print("✅ Success messages: \(successMessages)")
        print("🎉 Working endpoints found: \(workingEndpoints)")
        
        if workingEndpoints > 0 {
            print("\n🎉 Working Endpoints:")
            debugMessages.filter { $0.contains("🎉") }.forEach { print("  \($0)") }
        }
        
        print("\n📋 Full Debug Log:")
        debugMessages.forEach { print($0) }
    }
}

// Run the test
let test = ConnectivityTest()
test.runTest()

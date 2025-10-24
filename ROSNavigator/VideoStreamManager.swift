//
//  VideoStreamManager.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine
import Network

@MainActor
class VideoStreamManager: ObservableObject {
    @Published var isConnected = false
    @Published var rgbStreamURL: URL?
    @Published var heatmapStreamURL: URL?
    @Published var irStreamURL: URL?
    @Published var connectionError: String?
    @Published var isRetrying = false
    
    let serverIP: String
    private let serverPort: Int
    private var cancellables = Set<AnyCancellable>()
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 5
    private let baseRetryDelay: TimeInterval = 2.0
    
    init(serverIP: String = "192.168.1.49", serverPort: Int = 8080) {
        self.serverIP = serverIP
        self.serverPort = serverPort
    }
    
    func startStreams() {
        // Create stream URLs for RGB and heatmap camera feeds using the serverIP parameter
        rgbStreamURL = URL(string: "http://\(serverIP):\(serverPort)/stream?topic=/object_detection_overlay/image_raw")
        heatmapStreamURL = URL(string: "http://\(serverIP):\(serverPort)/stream?topic=/heatmap_3d/image_raw")
        irStreamURL = nil
        
        print("📹 Created stream URLs:")
        print("   RGB (Object Detection Overlay): \(rgbStreamURL?.absoluteString ?? "nil")")
        print("   Heatmap: \(heatmapStreamURL?.absoluteString ?? "nil")")
        print("   IR: Disabled")
        
        // Set connection as ready - let the WebView handle the actual connection
        isConnected = true
        connectionError = nil
        print("📹 Stream URLs configured - ready for WebView connection")
    }
    
    // Simple method to get stream URLs for WebView usage
    func getStreamURL(for camera: CameraType) -> URL? {
        switch camera {
        case .rgb:
            return rgbStreamURL
        case .heatmap:
            return heatmapStreamURL
        case .ir:
            return nil // IR camera disabled
        }
    }
    
    // Test if a specific stream URL is accessible
    func testStreamURL(_ url: URL, completion: @escaping (Bool, String?) -> Void) {
        print("📹 Testing stream URL: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (compatible; ROSNavigator/1.0)", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("📹 Stream URL test failed: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else if let httpResponse = response as? HTTPURLResponse {
                print("📹 Stream URL response: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("📹 Stream URL test successful!")
                    completion(true, nil)
                } else {
                    let errorMsg = "HTTP \(httpResponse.statusCode)"
                    print("📹 Stream URL test failed: \(errorMsg)")
                    completion(false, errorMsg)
                }
            } else {
                print("📹 Stream URL test failed: No response")
                completion(false, "No response received")
            }
        }
        
        task.resume()
    }
    
    enum CameraType {
        case rgb, heatmap, ir
    }
    
    private func testConnection() {
        guard let testURL = rgbStreamURL else { return }
        
        print("📹 Testing connection to: \(testURL.absoluteString)")
        connectionError = nil
        
        // First, test basic network connectivity
        testNetworkConnectivity { [weak self] isReachable in
            Task { @MainActor [weak self] in
                if !isReachable {
                    self?.handleConnectionFailure("Network unreachable")
                    return
                }
                
                // If network is reachable, test the stream endpoint
                self?.testStreamEndpoint(url: testURL)
            }
        }
    }
    
    private func testNetworkConnectivity(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        monitor.pathUpdateHandler = { path in
            let isReachable = path.status == .satisfied
            print("📹 Network connectivity: \(isReachable ? "Available" : "Unavailable")")
            monitor.cancel()
            
            if isReachable {
                // Test direct TCP connection to the server
                let connection = NWConnection(host: NWEndpoint.Host(self.serverIP), port: NWEndpoint.Port(integerLiteral: UInt16(self.serverPort)), using: .tcp)
                connection.stateUpdateHandler = { (state: NWConnection.State) in
                    switch state {
                    case .ready:
                        print("📹 TCP connection to \(self.serverIP):\(self.serverPort) - READY")
                        connection.cancel()
                        completion(true)
                    case .failed(let error):
                        print("📹 TCP connection to \(self.serverIP):\(self.serverPort) - FAILED: \(error)")
                        connection.cancel()
                        completion(false)
                    case .cancelled:
                        print("📹 TCP connection to \(self.serverIP):\(self.serverPort) - CANCELLED")
                    default:
                        break
                    }
                }
                connection.start(queue: queue)
                
                // Timeout after 3 seconds for TCP connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    connection.cancel()
                    print("📹 TCP connection timeout - assuming connection failed")
                    completion(false)
                }
            } else {
                completion(false)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func testStreamEndpoint(url: URL) {
        print("📹 Testing stream endpoint: \(url.absoluteString)")
        
        // Create a custom URLSession with longer timeouts for streaming
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0  // Reduced from 15s
        config.timeoutIntervalForResource = 20.0  // Reduced from 30s
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.httpMaximumConnectionsPerHost = 1
        
        let session = URLSession(configuration: config)
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0  // Reduced from 15s
        request.setValue("image/jpeg", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.setValue("Mozilla/5.0 (compatible; ROSNavigator/1.0)", forHTTPHeaderField: "User-Agent")
        
        print("📹 Making HTTP request to stream endpoint with timeout: \(request.timeoutInterval)s")
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                if let error = error {
                    print("📹 Stream endpoint test error: \(error.localizedDescription)")
                    print("📹 Error code: \((error as NSError).code)")
                    print("📹 Error domain: \((error as NSError).domain)")
                    self?.handleConnectionFailure(error.localizedDescription)
                } else if let httpResponse = response as? HTTPURLResponse {
                    print("📹 Stream endpoint response: \(httpResponse.statusCode)")
                    print("📹 Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
                    print("📹 Content-Length: \(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "unknown")")
                    
                    if httpResponse.statusCode == 200 {
                        print("📹 Stream endpoint test successful!")
                        self?.handleConnectionSuccess()
                    } else {
                        let errorMsg = "HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                        print("📹 Stream endpoint test failed: \(errorMsg)")
                        self?.handleConnectionFailure(errorMsg)
                    }
                } else {
                    print("📹 Stream endpoint test failed: No response received")
                    self?.handleConnectionFailure("No response received")
                }
            }
        }
        
        task.resume()
        print("📹 HTTP request task started")
    }
    
    private func handleConnectionSuccess() {
        print("📹 Connection test successful")
        isConnected = true
        connectionError = nil
        isRetrying = false
        retryCount = 0
        retryTimer?.invalidate()
        retryTimer = nil
    }
    
    private func handleConnectionFailure(_ error: String) {
        print("📹 Connection test failed: \(error)")
        isConnected = false
        connectionError = error
        retryCount += 1
        
        if retryCount < maxRetries {
            scheduleRetry()
        } else {
            print("📹 Max retries reached, giving up")
            isRetrying = false
        }
    }
    
    private func scheduleRetry() {
        let delay = baseRetryDelay * pow(2.0, Double(retryCount - 1)) // Exponential backoff
        print("📹 Scheduling retry \(retryCount)/\(maxRetries) in \(delay)s")
        
        isRetrying = true
        retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.testConnection()
            }
        }
    }
    
    func stopStreams() {
        retryTimer?.invalidate()
        retryTimer = nil
        rgbStreamURL = nil
        heatmapStreamURL = nil
        irStreamURL = nil
        isConnected = false
        connectionError = nil
        isRetrying = false
        retryCount = 0
    }
    
    func retryConnection() {
        retryCount = 0
        testConnection()
    }
}

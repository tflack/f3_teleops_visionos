//
//  VideoStreamManager.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine

@MainActor
class VideoStreamManager: ObservableObject {
    @Published var isConnected = false
    @Published var rgbStreamURL: URL?
    @Published var heatmapStreamURL: URL?
    @Published var irStreamURL: URL?
    
    private let serverIP: String
    private let serverPort: Int
    private var cancellables = Set<AnyCancellable>()
    
    init(serverIP: String = "192.168.1.49", serverPort: Int = 8080) {
        self.serverIP = serverIP
        self.serverPort = serverPort
    }
    
    func startStreams() {
        // Create stream URLs for the three camera feeds
        rgbStreamURL = URL(string: "http://\(serverIP):\(serverPort)/stream?topic=/depth_cam/rgb/image_raw")
        heatmapStreamURL = URL(string: "http://\(serverIP):\(serverPort)/stream?topic=/heatmap_3d/image_raw")
        irStreamURL = URL(string: "http://\(serverIP):\(serverPort)/stream?topic=/depth_cam/ir/image_raw")
        
        // Test connection to video server
        testConnection()
    }
    
    private func testConnection() {
        guard let testURL = rgbStreamURL else { return }
        
        var request = URLRequest(url: testURL)
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            Task { @MainActor in
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    self?.isConnected = true
                } else {
                    self?.isConnected = false
                }
            }
        }.resume()
    }
    
    func stopStreams() {
        rgbStreamURL = nil
        heatmapStreamURL = nil
        irStreamURL = nil
        isConnected = false
    }
}

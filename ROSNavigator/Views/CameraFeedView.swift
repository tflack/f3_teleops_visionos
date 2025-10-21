//
//  CameraFeedView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import AVFoundation

struct CameraFeedView: View {
    let ros2Manager: ROS2WebSocketManager
    @State private var videoStreamManager = VideoStreamManager()
    @State private var detectedObjects: [DetectedObjectInfo] = []
    
    var body: some View {
        ZStack {
            // Main camera feed
            VideoPlayerView(streamURL: videoStreamManager.rgbStreamURL)
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
            
            // Object detection overlay
            if !detectedObjects.isEmpty {
                ObjectDetectionOverlayView(objects: detectedObjects)
            }
            
            // LIDAR overlay
            LidarOverlayView(ros2Manager: ros2Manager)
                .opacity(0.7)
            
            // Stream status indicator
            VStack {
                HStack {
                    Spacer()
                    StreamStatusIndicator(streamManager: videoStreamManager)
                        .padding(8)
                }
                Spacer()
            }
        }
        .onAppear {
            setupVideoStreams()
            setupObjectDetection()
        }
    }
    
    private func setupVideoStreams() {
        videoStreamManager.startStreams()
    }
    
    private func setupObjectDetection() {
        ros2Manager.subscribe(to: "/detected_objects", messageType: "interfaces/DetectedObjects") { message in
            if let data = message as? [String: Any],
               let objectsData = data["objects"] as? [[String: Any]] {
                Task { @MainActor in
                    detectedObjects = objectsData.compactMap { objData in
                        // Parse detected object data
                        guard let className = objData["class_name"] as? String,
                              let confidence = objData["confidence"] as? Double,
                              let positionData = objData["position"] as? [String: Any],
                              let boundingBoxData = objData["bounding_box"] as? [String: Any],
                              let distance = objData["distance"] as? Double else {
                            return nil
                        }
                        
                        // Create DetectedObjectInfo
                        let position = DetectedObjects.DetectedObject.Position(
                            x: positionData["x"] as? Double ?? 0,
                            y: positionData["y"] as? Double ?? 0,
                            z: positionData["z"] as? Double ?? 0
                        )
                        
                        let boundingBox = DetectedObjects.DetectedObject.BoundingBox(
                            x: boundingBoxData["x"] as? Int ?? 0,
                            y: boundingBoxData["y"] as? Int ?? 0,
                            width: boundingBoxData["width"] as? Int ?? 0,
                            height: boundingBoxData["height"] as? Int ?? 0
                        )
                        
                        let detectedObject = DetectedObjects.DetectedObject(
                            className: className,
                            confidence: confidence,
                            position: position,
                            boundingBox: boundingBox,
                            distance: distance
                        )
                        
                        return DetectedObjectInfo(from: detectedObject)
                    }
                }
            }
        }
    }
}

struct VideoPlayerView: View {
    let streamURL: URL?
    
    var body: some View {
        Group {
            if let url = streamURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(.black)
                        .overlay {
                            VStack {
                                Image(systemName: "video.slash")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                Text("Loading camera feed...")
                                    .foregroundColor(.white)
                                    .font(.caption)
                            }
                        }
                }
            } else {
                Rectangle()
                    .fill(.black)
                    .overlay {
                        VStack {
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            Text("No camera feed available")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    }
            }
        }
    }
}

struct StreamStatusIndicator: View {
    let streamManager: VideoStreamManager
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(streamManager.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(streamManager.isConnected ? "LIVE" : "OFFLINE")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.black.opacity(0.6), in: Capsule())
    }
}

#Preview {
    CameraFeedView(ros2Manager: ROS2WebSocketManager())
        .frame(width: 640, height: 360)
}

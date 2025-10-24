//
//  CameraFeedView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import AVFoundation
import AVKit

struct CameraFeedView: View {
    let ros2Manager: ROS2WebSocketManager
    @State private var videoStreamManager: VideoStreamManager
    @State private var detectedObjects: [DetectedObjectInfo] = []
    @Binding var selectedCamera: VideoStreamManager.CameraType
    
    init(ros2Manager: ROS2WebSocketManager, selectedCamera: Binding<VideoStreamManager.CameraType> = .constant(.rgb)) {
        self.ros2Manager = ros2Manager
        self._selectedCamera = selectedCamera
        // Extract IP from ros2Manager's serverIP
        let serverIP = ros2Manager.serverIP
        let streamManager = VideoStreamManager(serverIP: serverIP)
        // Start streams immediately to ensure URLs are available
        streamManager.startStreams()
        self._videoStreamManager = State(initialValue: streamManager)
    }
    
    var body: some View {
        ZStack {
            // Main camera feed using MJPEG approach (like f3_teleops)
            if let streamURL = videoStreamManager.getStreamURL(for: selectedCamera) {
                SimpleMJPEGView(
                    streamURL: streamURL,
                    isLoading: .constant(false),
                    hasError: .constant(false),
                    errorMessage: .constant("")
                )
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
                .onAppear {
                    print("📹 CameraFeedView appeared!")
                    print("📹 Using MJPEG approach like f3_teleops: \(streamURL.absoluteString)")
                }
            } else {
                // Fallback if no stream URL available - make this more visible for debugging
                Rectangle()
                    .fill(Color.red.opacity(0.8))
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            Text("No stream URL available")
                                .foregroundColor(.white)
                                .font(.headline)
                            Text("Camera: \(selectedCamera)")
                                .foregroundColor(.white)
                            Text("Server IP: \(ros2Manager.serverIP)")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    )
                    .onAppear {
                        print("📹 CameraFeedView fallback appeared - no stream URL!")
                        print("📹 Selected camera: \(selectedCamera)")
                        print("📹 Server IP: \(ros2Manager.serverIP)")
                        print("📹 VideoStreamManager connected: \(videoStreamManager.isConnected)")
                    }
            }
            
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

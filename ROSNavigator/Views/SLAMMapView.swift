//
//  SLAMMapView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import CoreGraphics

struct SLAMMapView: View {
    let ros2Manager: ROS2WebSocketManager
    @State private var mapData: OccupancyGrid?
    @State private var robotPose: (x: Double, y: Double, heading: Double)?
    @State private var isConnected = false
    
    var body: some View {
        ZStack {
            // SLAM map canvas
            SLAMCanvasView(mapData: mapData, robotPose: robotPose)
                .background(.black)
            
            // Connection status
            VStack {
                HStack {
                    Spacer()
                    ConnectionIndicator(isConnected: isConnected)
                        .padding(8)
                }
                Spacer()
            }
            
            // Clear queue button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: clearSLAMQueue) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.red.opacity(0.7), in: Circle())
                    }
                    .padding(8)
                }
            }
            
            // No data message
            if mapData == nil {
                VStack(spacing: 8) {
                    Image(systemName: "map")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("SLAM Map Not Available")
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Topic: /map")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption2)
                    Text("SLAM system not running")
                        .foregroundColor(.orange)
                        .font(.caption2)
                    if !isConnected {
                        Text("Not connected to robot")
                            .foregroundColor(.red)
                            .font(.caption2)
                    }
                }
            }
        }
        .onAppear {
            setupSLAMSubscriptions()
        }
    }
    
    private func setupSLAMSubscriptions() {
        print("🗺️ Setting up SLAM subscriptions...")
        
        // Subscribe to map topic
        ros2Manager.subscribe(to: "/map", messageType: "nav_msgs/msg/OccupancyGrid") { message in
            print("🗺️ Received map message: \(message)")
            if let data = message as? [String: Any] {
                Task { @MainActor in
                    parseMapData(data)
                }
            }
        }
        
        // Subscribe to TF topic for robot pose
        ros2Manager.subscribe(to: "/tf", messageType: "tf2_msgs/msg/TFMessage") { message in
            print("🗺️ Received TF message: \(message)")
            if let data = message as? [String: Any] {
                Task { @MainActor in
                    parseRobotPose(data)
                }
            }
        }
        
        print("🗺️ SLAM subscriptions setup complete")
    }
    
    private func parseMapData(_ data: [String: Any]) {
        guard let info = data["info"] as? [String: Any],
              let dataArray = data["data"] as? [Int8] else { return }
        
        let resolution = info["resolution"] as? Double ?? 0.05
        let width = info["width"] as? UInt32 ?? 0
        let height = info["height"] as? UInt32 ?? 0
        
        var origin: OccupancyGrid.MapMetaData.Pose?
        if let originData = info["origin"] as? [String: Any] {
            let position = originData["position"] as? [String: Any] ?? [:]
            let orientation = originData["orientation"] as? [String: Any] ?? [:]
            
            origin = OccupancyGrid.MapMetaData.Pose(
                position: OccupancyGrid.MapMetaData.Pose.Point(
                    x: position["x"] as? Double ?? 0,
                    y: position["y"] as? Double ?? 0,
                    z: position["z"] as? Double ?? 0
                ),
                orientation: OccupancyGrid.MapMetaData.Pose.Quaternion(
                    x: orientation["x"] as? Double ?? 0,
                    y: orientation["y"] as? Double ?? 0,
                    z: orientation["z"] as? Double ?? 0,
                    w: orientation["w"] as? Double ?? 1
                )
            )
        }
        
        let header = OccupancyGrid.Header(
            stamp: OccupancyGrid.Header.TimeStamp(sec: 0, nanosec: 0),
            frameId: "map"
        )
        
        let mapMetaData = OccupancyGrid.MapMetaData(
            mapLoadTime: OccupancyGrid.MapMetaData.TimeStamp(sec: 0, nanosec: 0),
            resolution: resolution,
            width: width,
            height: height,
            origin: origin ?? OccupancyGrid.MapMetaData.Pose(
                position: OccupancyGrid.MapMetaData.Pose.Point(x: 0, y: 0, z: 0),
                orientation: OccupancyGrid.MapMetaData.Pose.Quaternion(x: 0, y: 0, z: 0, w: 1)
            )
        )
        
        mapData = OccupancyGrid(
            header: header,
            info: mapMetaData,
            data: dataArray
        )
        
        isConnected = true
    }
    
    private func parseRobotPose(_ data: [String: Any]) {
        guard let transforms = data["transforms"] as? [[String: Any]] else { return }
        
        for transform in transforms {
            if let childFrameId = transform["child_frame_id"] as? String,
               (childFrameId == "base_link" || childFrameId == "base_footprint"),
               let transformData = transform["transform"] as? [String: Any],
               let translation = transformData["translation"] as? [String: Any],
               let rotation = transformData["rotation"] as? [String: Any] {
                
                let x = translation["x"] as? Double ?? 0
                let y = translation["y"] as? Double ?? 0
                
                // Convert quaternion to heading
                let qx = rotation["x"] as? Double ?? 0
                let qy = rotation["y"] as? Double ?? 0
                let qz = rotation["z"] as? Double ?? 0
                let qw = rotation["w"] as? Double ?? 1
                
                let heading = atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy * qy + qz * qz))
                
                robotPose = (x: x, y: y, heading: heading * 180 / .pi)
                break
            }
        }
    }
    
    private func clearSLAMQueue() {
        ros2Manager.callService(service: "/slam_toolbox/clear_queue", request: [:]) { result in
            switch result {
            case .success:
                print("✅ SLAM queue cleared")
            case .failure(let error):
                print("❌ Failed to clear SLAM queue: \(error)")
            }
        }
    }
}

struct SLAMCanvasView: View {
    let mapData: OccupancyGrid?
    let robotPose: (x: Double, y: Double, heading: Double)?
    
    var body: some View {
        Canvas { context, size in
            guard let mapData = mapData, mapData.isValid else { return }
            
            let info = mapData.info
            let scaleX = size.width / CGFloat(info.width)
            let scaleY = size.height / CGFloat(info.height)
            let scale = min(scaleX, scaleY) * 0.95
            
            let offsetX = (size.width - CGFloat(info.width) * scale) / 2
            let offsetY = (size.height - CGFloat(info.height) * scale) / 2
            
            // Draw occupancy grid
            for y in 0..<Int(info.height) {
                for x in 0..<Int(info.width) {
                    if let cellValue = mapData.occupancyAt(x: x, y: y) {
                        let color: Color
                        switch cellValue {
                        case -1: // Unknown
                            color = .gray.opacity(0.3)
                        case 0: // Free
                            color = .black
                        case 100: // Occupied
                            color = .white
                        default: // Probabilistic
                            let intensity = Double(cellValue) / 100.0
                            color = Color(white: intensity)
                        }
                        
                        context.fill(
                            Path(CGRect(
                                x: offsetX + CGFloat(x) * scale,
                                y: offsetY + CGFloat(y) * scale,
                                width: scale,
                                height: scale
                            )),
                            with: .color(color)
                        )
                    }
                }
            }
            
            // Draw robot pose
            if let pose = robotPose {
                let robotX = offsetX + CGFloat((pose.x - info.origin.position.x) / info.resolution) * scale
                let robotY = offsetY + CGFloat((pose.y - info.origin.position.y) / info.resolution) * scale
                
                // Robot position
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: robotX - 4,
                        y: robotY - 4,
                        width: 8,
                        height: 8
                    )),
                    with: .color(.green)
                )
                
                // Robot orientation
                let headingRad = pose.heading * .pi / 180
                let endX = robotX + cos(headingRad) * 10
                let endY = robotY + sin(headingRad) * 10
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: robotX, y: robotY))
                        path.addLine(to: CGPoint(x: endX, y: endY))
                    },
                    with: .color(.green),
                    lineWidth: 2
                )
            }
        }
    }
}

#Preview {
    SLAMMapView(ros2Manager: ROS2WebSocketManager.shared)
        .frame(width: 300, height: 200)
}

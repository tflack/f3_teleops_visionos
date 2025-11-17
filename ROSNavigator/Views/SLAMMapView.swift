//
//  SLAMMapView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import CoreGraphics
import Combine

struct SLAMMapView: View {
    let ros2Manager: ROS2WebSocketManager
    @State private var mapData: OccupancyGrid?
    @State private var robotPose: (x: Double, y: Double, heading: Double)?
    @State private var isConnected = false
    @State private var lastDataReceived: Date?
    @State private var connectionMonitorTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // SLAM map canvas
            SLAMCanvasView(mapData: mapData, robotPose: robotPose)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Ensure connection is established first
            if case .disconnected = ros2Manager.connectionState {
                ros2Manager.connect()
            }
            
            // Set up subscriptions (they will be sent when connection is ready)
            setupSLAMSubscriptions()
            startConnectionMonitoring()
            
            // Also subscribe when connection is established
            Task {
                for await state in ros2Manager.$connectionState.values {
                    if case .connected = state {
                        setupSLAMSubscriptions()
                        break
                    }
                }
            }
        }
        .onDisappear {
            stopConnectionMonitoring()
        }
        .onChange(of: ros2Manager.isConnected) { _, newValue in
            isConnected = newValue
            if newValue {
                setupSLAMSubscriptions()
            }
        }
    }
    
    private func setupSLAMSubscriptions() {
        // Subscribe to map topic (using ROS1 format for rosbridge, matching f3_teleops)
        ros2Manager.subscribe(to: "/map", messageType: "nav_msgs/OccupancyGrid") { message in
            if let messageDict = message as? [String: Any] {
                Task { @MainActor in
                    parseMapData(messageDict)
                }
            }
        }
        
        // Subscribe to TF topic for robot pose (using ROS1 format for rosbridge, matching f3_teleops)
        ros2Manager.subscribe(to: "/tf", messageType: "tf2_msgs/TFMessage") { message in
            if let data = message as? [String: Any] {
                Task { @MainActor in
                    parseRobotPose(data)
                }
            }
        }
    }
    
    private func parseMapData(_ data: [String: Any]) {
        guard let info = data["info"] as? [String: Any] else {
            print("❌ Failed to parse map data: missing 'info' key")
            return
        }
        
        // Handle both [Int8] and [Int] data arrays (rosbridge may send either)
        var dataArray: [Int8] = []
        if let dataValue = data["data"] {
            if let int8Array = dataValue as? [Int8] {
                dataArray = int8Array
            } else if let intArray = dataValue as? [Int] {
                dataArray = intArray.map { Int8($0) }
            } else if let intArray = dataValue as? [Int32] {
                dataArray = intArray.map { Int8($0) }
            } else if let nsArray = dataValue as? NSArray {
                // Try to convert NSArray to [Int8]
                var converted: [Int8] = []
                for element in nsArray {
                    if let intVal = element as? Int {
                        converted.append(Int8(intVal))
                    } else if let int8Val = element as? Int8 {
                        converted.append(int8Val)
                    } else if let int32Val = element as? Int32 {
                        converted.append(Int8(int32Val))
                    }
                }
                if converted.count == nsArray.count {
                    dataArray = converted
                } else {
                    print("❌ Failed to parse map data: data array type not recognized")
                    return
                }
            } else {
                print("❌ Failed to parse map data: data array type not recognized")
                return
            }
        } else {
            print("❌ Failed to parse map data: missing 'data' key")
            return
        }
        
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
        
        // Parse header if available
        var header = OccupancyGrid.Header(
            stamp: OccupancyGrid.Header.TimeStamp(sec: 0, nanosec: 0),
            frameId: "map"
        )
        if let headerData = data["header"] as? [String: Any] {
            if let frameId = headerData["frame_id"] as? String {
                header = OccupancyGrid.Header(
                    stamp: OccupancyGrid.Header.TimeStamp(sec: 0, nanosec: 0),
                    frameId: frameId
                )
            }
        }
        
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
        
        // Update connection status based on data receipt
        isConnected = true
        lastDataReceived = Date()
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
                
                // Convert quaternion to heading (yaw angle)
                let qx = rotation["x"] as? Double ?? 0
                let qy = rotation["y"] as? Double ?? 0
                let qz = rotation["z"] as? Double ?? 0
                let qw = rotation["w"] as? Double ?? 1
                
                // Calculate yaw from quaternion (same formula as f3_teleops)
                let heading = atan2(2 * (qw * qz + qx * qy), 1 - 2 * (qy * qy + qz * qz))
                
                robotPose = (x: x, y: y, heading: heading)
                lastDataReceived = Date()
                break
            }
        }
    }
    
    private func startConnectionMonitoring() {
        stopConnectionMonitoring() // Stop any existing task
        
        // Monitor data receipt and update connection status (matching f3_teleops approach)
        // Use Task instead of Timer to properly work with @State in SwiftUI
        connectionMonitorTask = Task { @MainActor in
            while !Task.isCancelled {
                if let lastReceived = lastDataReceived {
                    let timeSinceLastData = Date().timeIntervalSince(lastReceived)
                    // If no data received for 5 seconds, mark as offline (matching f3_teleops timeout)
                    if timeSinceLastData > 5.0 {
                        isConnected = false
                    } else {
                        isConnected = true
                    }
                } else if ros2Manager.isConnected {
                    isConnected = true
                } else {
                    isConnected = false
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
    }
    
    private func stopConnectionMonitoring() {
        connectionMonitorTask?.cancel()
        connectionMonitorTask = nil
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
            // Scale to fill the entire view (stretch to fit)
            let scaleX = size.width / CGFloat(info.width)
            let scaleY = size.height / CGFloat(info.height)
            
            // No offset needed - map fills from (0,0)
            let offsetX: CGFloat = 0
            let offsetY: CGFloat = 0
            
            // Draw occupancy grid
            for y in 0..<Int(info.height) {
                for x in 0..<Int(info.width) {
                    if let cellValue = mapData.occupancyAt(x: x, y: y) {
                        let color: Color
                        switch cellValue {
                        case -1: // Unknown - gray (#333333), matching f3_teleops
                            color = Color(red: 0.2, green: 0.2, blue: 0.2)
                        case 0: // Free - black, matching f3_teleops
                            color = .black
                        case 100: // Occupied - white, matching f3_teleops
                            color = .white
                        default: // Probabilistic - interpolated grayscale, matching f3_teleops
                            let intensity = Double(cellValue) / 100.0
                            color = Color(white: intensity)
                        }
                        
                        context.fill(
                            Path(CGRect(
                                x: offsetX + CGFloat(x) * scaleX,
                                y: offsetY + CGFloat(y) * scaleY,
                                width: scaleX,
                                height: scaleY
                            )),
                            with: .color(color)
                        )
                    }
                }
            }
            
            // Draw robot pose
            if let pose = robotPose {
                let robotX = offsetX + CGFloat((pose.x - info.origin.position.x) / info.resolution) * scaleX
                let robotY = offsetY + CGFloat((pose.y - info.origin.position.y) / info.resolution) * scaleY
                
                // Robot position (green circle, matching f3_teleops)
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: robotX - 8,
                        y: robotY - 8,
                        width: 16,
                        height: 16
                    )),
                    with: .color(.green)
                )
                
                // Robot orientation (heading is in radians, matching f3_teleops)
                let endX = robotX + cos(pose.heading) * 15
                let endY = robotY + sin(pose.heading) * 15
                
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: robotX, y: robotY))
                        path.addLine(to: CGPoint(x: endX, y: endY))
                    },
                    with: .color(.green),
                    lineWidth: 3
                )
            }
        }
    }
}

#Preview {
    SLAMMapView(ros2Manager: ROS2WebSocketManager.shared)
        .frame(width: 300, height: 200)
}

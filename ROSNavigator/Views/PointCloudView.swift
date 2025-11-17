//
//  PointCloudView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import Combine

struct PointCloudView: View {
    let ros2Manager: ROS2WebSocketManager
    @State private var pointCloudData: PointCloud2?
    @State private var isConnected = false
    @State private var rotation = (pitch: 17.0, yaw: -168.0)
    @State private var zoom: Double = 3.0
    @State private var isDragging = false
    @State private var lastDataReceived: Date?
    @State private var connectionMonitorTask: Task<Void, Never>?
    @State private var pointCount: Int = 0
    
    var body: some View {
        ZStack {
            // Point cloud visualization
            PointCloudCanvasView(
                pointCloudData: pointCloudData,
                rotation: rotation,
                zoom: zoom
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.04, green: 0.04, blue: 0.04)) // Dark background matching f3_teleops
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let sensitivity: Double = 0.3
                        rotation.yaw += value.translation.width * sensitivity
                        rotation.pitch = max(-89, min(89, rotation.pitch - value.translation.height * sensitivity))
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
            .onTapGesture(count: 2) {
                // Reset view on double tap
                withAnimation(.easeInOut(duration: 0.5)) {
                    rotation = (pitch: 17.0, yaw: -168.0)
                    zoom = 3.0
                }
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoom = max(0.5, min(10.0, Double(value)))
                    }
            )
            
            // Connection status
            VStack {
                HStack {
                    Spacer()
                    ConnectionIndicator(isConnected: isConnected)
                        .padding(8)
                }
                Spacer()
            }
            
            // Reset view button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: resetView) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(.blue.opacity(0.7), in: Circle())
                    }
                    .padding(8)
                }
            }
            
            // No data message
            if pointCloudData == nil {
                VStack(spacing: 8) {
                    Image(systemName: "cube.3d")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("Waiting for point cloud...")
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Topic: /cloud_map")
                        .foregroundColor(.white.opacity(0.7))
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
            setupPointCloudSubscription()
            startConnectionMonitoring()
            
            // Also subscribe when connection is established
            Task {
                for await state in ros2Manager.$connectionState.values {
                    if case .connected = state {
                        setupPointCloudSubscription()
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
                setupPointCloudSubscription()
            }
        }
    }
    
    private func setupPointCloudSubscription() {
        // Subscribe to point cloud topic (using ROS1 format for rosbridge, matching f3_teleops)
        ros2Manager.subscribe(to: "/cloud_map", messageType: "sensor_msgs/PointCloud2") { message in
            if let data = message as? [String: Any] {
                Task { @MainActor in
                    parsePointCloudData(data)
                }
            }
        }
    }
    
    private func parsePointCloudData(_ data: [String: Any]) {
        guard let width = data["width"] as? UInt32 ?? (data["width"] as? Int).map({ UInt32($0) }),
              let height = data["height"] as? UInt32 ?? (data["height"] as? Int).map({ UInt32($0) }),
              let fields = data["fields"] as? [[String: Any]],
              let pointStep = data["point_step"] as? UInt32 ?? (data["point_step"] as? Int).map({ UInt32($0) }) else {
            print("❌ Failed to parse point cloud: missing required fields")
            return
        }
        
        let totalPoints = Int(width * height)
        guard totalPoints > 0 && pointStep > 0 else {
            print("❌ Invalid point cloud data: width=\(width), height=\(height), pointStep=\(pointStep)")
            return
        }
        
        // Handle data - can be base64 string or array (matching f3_teleops)
        var binaryData: Data?
        
        if let dataString = data["data"] as? String {
            // Base64 encoded data (common in rosbridge)
            binaryData = Data(base64Encoded: dataString)
        } else if let dataArray = data["data"] as? [UInt8] {
            // Array of bytes
            binaryData = Data(dataArray)
        } else if let dataArray = data["data"] as? [Int] {
            // Array of Ints - convert to UInt8
            binaryData = Data(dataArray.map { UInt8($0 & 0xFF) })
        } else if let nsArray = data["data"] as? NSArray {
            // NSArray - try to convert
            var bytes: [UInt8] = []
            for element in nsArray {
                if let intVal = element as? Int {
                    bytes.append(UInt8(intVal & 0xFF))
                } else if let uint8Val = element as? UInt8 {
                    bytes.append(uint8Val)
                }
            }
            if bytes.count > 0 {
                binaryData = Data(bytes)
            }
        }
        
        guard let binaryData = binaryData else {
            print("❌ Failed to parse point cloud: data format not recognized")
            return
        }
        
        // Parse header if available
        var header = PointCloud2.Header(
            stamp: PointCloud2.Header.TimeStamp(sec: 0, nanosec: 0),
            frameId: "map"
        )
        if let headerData = data["header"] as? [String: Any] {
            if let frameId = headerData["frame_id"] as? String {
                header = PointCloud2.Header(
                    stamp: PointCloud2.Header.TimeStamp(sec: 0, nanosec: 0),
                    frameId: frameId
                )
            }
        }
        
        let pointFields = fields.map { field in
            PointCloud2.PointField(
                name: field["name"] as? String ?? "",
                offset: (field["offset"] as? UInt32) ?? (field["offset"] as? Int).map({ UInt32($0) }) ?? 0,
                datatype: (field["datatype"] as? UInt8) ?? (field["datatype"] as? Int).map({ UInt8($0) }) ?? 0,
                count: (field["count"] as? UInt32) ?? (field["count"] as? Int).map({ UInt32($0) }) ?? 0
            )
        }
        
        pointCloudData = PointCloud2(
            header: header,
            height: height,
            width: width,
            fields: pointFields,
            isBigendian: data["is_bigendian"] as? Bool ?? false,
            pointStep: pointStep,
            rowStep: (data["row_step"] as? UInt32) ?? (data["row_step"] as? Int).map({ UInt32($0) }) ?? 0,
            data: binaryData,
            isDense: data["is_dense"] as? Bool ?? true
        )
        
        // Update point count
        if let pointCloudData = pointCloudData {
            pointCount = pointCloudData.totalPoints
        }
        
        // Update connection status based on data receipt
        isConnected = true
        lastDataReceived = Date()
    }
    
    private func startConnectionMonitoring() {
        stopConnectionMonitoring() // Stop any existing task
        
        // Monitor data receipt and update connection status (matching f3_teleops approach)
        connectionMonitorTask = Task { @MainActor in
            while !Task.isCancelled {
                if let lastReceived = lastDataReceived {
                    let timeSinceLastData = Date().timeIntervalSince(lastReceived)
                    // If no data received for 5 minutes, mark as offline (matching f3_teleops timeout)
                    if timeSinceLastData > 5 * 60 {
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
    
    private func resetView() {
        withAnimation(.easeInOut(duration: 0.5)) {
            rotation = (pitch: 17.0, yaw: -168.0)
            zoom = 3.0
        }
    }
}

struct PointCloudCanvasView: View {
    let pointCloudData: PointCloud2?
    let rotation: (pitch: Double, yaw: Double)
    let zoom: Double
    
    var body: some View {
        Canvas { context, size in
            guard let pointCloudData = pointCloudData else {
                // Draw waiting message
                var path = Path()
                path.addRect(CGRect(origin: .zero, size: size))
                context.fill(path, with: .color(Color(red: 0.04, green: 0.04, blue: 0.04)))
                return
            }
            
            // Fill background
            var bgPath = Path()
            bgPath.addRect(CGRect(origin: .zero, size: size))
            context.fill(bgPath, with: .color(Color(red: 0.04, green: 0.04, blue: 0.04)))
            
            // Sample points (matching f3_teleops max of 100,000)
            let points = pointCloudData.sampledPoints(maxCount: 100000)
            guard points.count > 0 else { return }
            
            let centerX = size.width / 2
            let centerY = size.height / 2
            // Scale matching f3_teleops: Math.min(width, height) * 0.4 / zoom
            let scale = min(size.width, size.height) * 0.4 / zoom
            
            let pitchRad = rotation.pitch * .pi / 180
            let yawRad = rotation.yaw * .pi / 180
            
            let cosPitch = cos(pitchRad)
            let sinPitch = sin(pitchRad)
            let cosYaw = cos(yawRad)
            let sinYaw = sin(yawRad)
            
            // Transform and project points (matching f3_teleops projection)
            var projectedPoints: [(x: Double, y: Double, z: Double, r: UInt8, g: UInt8, b: UInt8)] = []
            projectedPoints.reserveCapacity(points.count)
            
            for point in points {
                // Rotate around Y (yaw)
                let x = Double(point.x) * cosYaw - Double(point.z) * sinYaw
                let z = Double(point.x) * sinYaw + Double(point.z) * cosYaw
                let y = Double(point.y)
                
                // Rotate around X (pitch)
                let y2 = y * cosPitch - z * sinPitch
                let z2 = y * sinPitch + z * cosPitch
                
                // Skip points behind camera
                guard z2 < 10 else { continue }
                
                // Project to 2D
                let screenX = x * scale + centerX
                let screenY = -y2 * scale + centerY
                
                projectedPoints.append((x: screenX, y: screenY, z: z2, r: point.r, g: point.g, b: point.b))
            }
            
            // Sort by depth (back to front) for proper rendering
            projectedPoints.sort { $0.z > $1.z }
            
            // Draw points (matching f3_teleops: size = Math.max(3, 6 - p.z * 0.04))
            for p in projectedPoints {
                let pointSize = max(3.0, 6.0 - p.z * 0.04)
                var pointPath = Path()
                pointPath.addRect(CGRect(
                    x: p.x - pointSize/2,
                    y: p.y - pointSize/2,
                    width: pointSize,
                    height: pointSize
                ))
                context.fill(
                    pointPath,
                    with: .color(Color(
                        red: Double(p.r) / 255.0,
                        green: Double(p.g) / 255.0,
                        blue: Double(p.b) / 255.0
                    ))
                )
            }
        }
    }
}

#Preview {
    PointCloudView(ros2Manager: ROS2WebSocketManager.shared)
        .frame(width: 400, height: 400)
}

//
//  PointCloudView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import RealityKit

struct PointCloudView: View {
    let ros2Manager: ROS2WebSocketManager
    @State private var pointCloudData: PointCloud2?
    @State private var isConnected = false
    @State private var rotation = (pitch: 17.0, yaw: -168.0)
    @State private var zoom: Float = 3.0
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            // Point cloud visualization
            PointCloudCanvasView(
                pointCloudData: pointCloudData,
                rotation: rotation,
                zoom: zoom
            )
            .background(.black)
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
                rotation = (pitch: 17.0, yaw: -168.0)
                zoom = 3.0
            }
            .scaleEffect(CGFloat(zoom))
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        zoom = max(0.5, min(10.0, Float(value)))
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
                VStack {
                    Image(systemName: "cube.3d")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("Waiting for point cloud...")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
        }
        .onAppear {
            setupPointCloudSubscription()
        }
    }
    
    private func setupPointCloudSubscription() {
        ros2Manager.subscribe(to: "/cloud_map", messageType: "sensor_msgs/PointCloud2") { message in
            if let data = message as? [String: Any] {
                Task { @MainActor in
                    parsePointCloudData(data)
                }
            }
        }
    }
    
    private func parsePointCloudData(_ data: [String: Any]) {
        guard let width = data["width"] as? UInt32,
              let height = data["height"] as? UInt32,
              let fields = data["fields"] as? [[String: Any]],
              let pointStep = data["point_step"] as? UInt32,
              let dataString = data["data"] as? String else { return }
        
        // Note: Field parsing for XYZ and RGB offsets could be implemented here
        // if needed for more advanced point cloud processing
        
        // Convert base64 data to binary
        guard let binaryData = Data(base64Encoded: dataString) else { return }
        
        let header = PointCloud2.Header(
            stamp: PointCloud2.Header.TimeStamp(sec: 0, nanosec: 0),
            frameId: "map"
        )
        
        let pointFields = fields.map { field in
            PointCloud2.PointField(
                name: field["name"] as? String ?? "",
                offset: field["offset"] as? UInt32 ?? 0,
                datatype: field["datatype"] as? UInt8 ?? 0,
                count: field["count"] as? UInt32 ?? 0
            )
        }
        
        pointCloudData = PointCloud2(
            header: header,
            height: height,
            width: width,
            fields: pointFields,
            isBigendian: data["is_bigendian"] as? Bool ?? false,
            pointStep: pointStep,
            rowStep: data["row_step"] as? UInt32 ?? 0,
            data: binaryData,
            isDense: data["is_dense"] as? Bool ?? true
        )
        
        isConnected = true
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
    let zoom: Float
    
    var body: some View {
        Canvas { context, size in
            guard let pointCloudData = pointCloudData else { return }
            
            let points = pointCloudData.sampledPoints(maxCount: 50000) // Limit for performance
            let centerX = size.width / 2
            let centerY = size.height / 2
            let scale = min(size.width, size.height) * 0.4
            
            let pitchRad = rotation.pitch * .pi / 180
            let yawRad = rotation.yaw * .pi / 180
            
            let cosPitch = cos(pitchRad)
            let sinPitch = sin(pitchRad)
            let cosYaw = cos(yawRad)
            let sinYaw = sin(yawRad)
            
            // Transform and project points
            for point in points {
                // Rotate around Y (yaw)
                let x = Double(point.x) * cosYaw - Double(point.z) * sinYaw
                let z = Double(point.x) * sinYaw + Double(point.z) * cosYaw
                let y = Double(point.y)
                
                // Rotate around X (pitch)
                let y2 = y * cosPitch - z * sinPitch
                let z2 = y * sinPitch + z * cosPitch
                
                // Project to 2D
                let screenX = centerX + x * scale
                let screenY = centerY - y2 * scale
                
                // Skip points behind camera
                guard z2 < 10 else { continue }
                
                // Draw point
                let pointSize = max(1, 4 - z2 * 0.1)
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: screenX - pointSize/2,
                        y: screenY - pointSize/2,
                        width: pointSize,
                        height: pointSize
                    )),
                    with: .color(Color(
                        red: Double(point.r) / 255.0,
                        green: Double(point.g) / 255.0,
                        blue: Double(point.b) / 255.0
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

//
//  ObjectDetectionOverlayView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

struct ObjectDetectionOverlayView: View {
    let objects: [DetectedObjectInfo]
    @State private var selectedObjectIndex: Int? = nil
    
    var body: some View {
        ZStack {
            ForEach(Array(objects.enumerated()), id: \.offset) { index, object in
                ObjectBoundingBoxView(
                    object: object,
                    isSelected: selectedObjectIndex == index
                ) {
                    selectedObjectIndex = index
                    executePickAction(for: object)
                }
            }
        }
    }
    
    private func executePickAction(for object: DetectedObjectInfo) {
        // This would send a pick command to the robot
        print("🤖 Picking object: \(object.className) at distance \(object.distanceString)")
        // TODO: Send pick command via ROS2
    }
}

struct ObjectBoundingBoxView: View {
    let object: DetectedObjectInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                // Bounding box
                Rectangle()
                    .stroke(isSelected ? .yellow : .red, lineWidth: isSelected ? 3 : 2)
                    .frame(
                        width: CGFloat(object.boundingBox.width),
                        height: CGFloat(object.boundingBox.height)
                    )
                    .overlay(
                        // Object label
                        VStack {
                            HStack {
                                Text("🤖 \(object.className)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.7), in: Capsule())
                                Spacer()
                            }
                            Spacer()
                            HStack {
                                Text("\(object.confidencePercentage)%")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.7), in: Capsule())
                                Spacer()
                            }
                        }
                        .padding(4)
                    )
            }
        }
        .position(
            x: CGFloat(object.boundingBox.x + object.boundingBox.width / 2),
            y: CGFloat(object.boundingBox.y + object.boundingBox.height / 2)
        )
    }
}

struct LidarOverlayView: View {
    let ros2Manager: ROS2WebSocketManager
    @State private var scanData: LaserScan?
    
    var body: some View {
        Canvas { context, size in
            guard let scanData = scanData else { return }
            
            let centerX = size.width / 2
            let centerY = size.height / 2
            let maxRange: CGFloat = 12.0
            let scale = min(size.width, size.height) / (2 * maxRange)
            
            // Draw LIDAR points as overlay
            let validPoints = scanData.validPoints()
            for point in validPoints {
                let x = centerX + CGFloat(point.distance * cos(point.angle - .pi / 2)) * scale
                let y = centerY - CGFloat(point.distance * sin(point.angle - .pi / 2)) * scale
                
                // Only draw points in front of robot (roughly)
                let angle = point.angle
                if angle > -1.57 && angle < 1.57 { // ±90 degrees
                    context.fill(
                        Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                        with: .color(.red.opacity(0.6))
                    )
                }
            }
        }
        .onAppear {
            setupLidarOverlaySubscription()
        }
    }
    
    private func setupLidarOverlaySubscription() {
        ros2Manager.subscribe(to: "/scan", messageType: "sensor_msgs/LaserScan") { message in
            if let data = message as? [String: Any] {
                Task { @MainActor in
                    // Parse LaserScan data (same as LidarVisualizationView)
                    if let ranges = data["ranges"] as? [Double],
                       let angleMin = data["angle_min"] as? Double,
                       let angleMax = data["angle_max"] as? Double,
                       let angleIncrement = data["angle_increment"] as? Double,
                       let rangeMin = data["range_min"] as? Double,
                       let rangeMax = data["range_max"] as? Double {
                        
                        let header = LaserScan.Header(
                            stamp: LaserScan.Header.TimeStamp(sec: 0, nanosec: 0),
                            frameId: "laser"
                        )
                        
                        scanData = LaserScan(
                            header: header,
                            angleMin: angleMin,
                            angleMax: angleMax,
                            angleIncrement: angleIncrement,
                            timeIncrement: 0.0,
                            scanTime: 0.0,
                            rangeMin: rangeMin,
                            rangeMax: rangeMax,
                            ranges: ranges,
                            intensities: Array(repeating: 100.0, count: ranges.count)
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    ObjectDetectionOverlayView(objects: [
        DetectedObjectInfo(from: DetectedObjects.DetectedObject(
            className: "bottle",
            confidence: 0.85,
            position: DetectedObjects.DetectedObject.Position(x: 1.2, y: 0.5, z: 0.0),
            boundingBox: DetectedObjects.DetectedObject.BoundingBox(x: 100, y: 50, width: 80, height: 120),
            distance: 1.2
        ))
    ])
    .frame(width: 640, height: 360)
}

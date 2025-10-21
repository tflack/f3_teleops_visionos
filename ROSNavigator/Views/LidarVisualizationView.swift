//
//  LidarVisualizationView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import CoreGraphics

struct LidarVisualizationView: View {
    let ros2Manager: ROS2WebSocketManager
    @State private var scanData: LaserScan?
    @State private var isConnected = false
    
    var body: some View {
        ZStack {
            // LIDAR visualization canvas
            LidarCanvasView(scanData: scanData)
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
            
            // No data message
            if scanData == nil {
                VStack {
                    Image(systemName: "radar")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    Text("Waiting for LIDAR data...")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
        }
        .onAppear {
            setupLidarSubscription()
        }
    }
    
    private func setupLidarSubscription() {
        ros2Manager.subscribe(to: "/scan", messageType: "sensor_msgs/LaserScan") { message in
            if let data = message as? [String: Any] {
                Task { @MainActor in
                    // Parse LaserScan data
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
                        
                        isConnected = true
                    }
                }
            }
        }
    }
}

struct LidarCanvasView: View {
    let scanData: LaserScan?
    
    var body: some View {
        Canvas { context, size in
            guard let scanData = scanData else { return }
            
            let centerX = size.width / 2
            let centerY = size.height / 2
            let maxRange: CGFloat = 12.0
            let scale = min(size.width, size.height) / (2 * maxRange)
            
            // Draw range circles
            context.stroke(
                Path { path in
                    for r in stride(from: 2, through: Int(maxRange), by: 2) {
                        path.addEllipse(in: CGRect(
                            x: centerX - CGFloat(r) * scale,
                            y: centerY - CGFloat(r) * scale,
                            width: CGFloat(r) * 2 * scale,
                            height: CGFloat(r) * 2 * scale
                        ))
                    }
                },
                with: .color(.gray.opacity(0.3)),
                lineWidth: 1
            )
            
            // Draw crosshairs
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: 0))
                    path.addLine(to: CGPoint(x: centerX, y: size.height))
                    path.move(to: CGPoint(x: 0, y: centerY))
                    path.addLine(to: CGPoint(x: size.width, y: centerY))
                },
                with: .color(.gray.opacity(0.5)),
                lineWidth: 1
            )
            
            // Draw robot (center)
            context.fill(
                Path(ellipseIn: CGRect(
                    x: centerX - 6,
                    y: centerY - 6,
                    width: 12,
                    height: 12
                )),
                with: .color(.green)
            )
            
            // Draw robot direction
            context.stroke(
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: centerY))
                    path.addLine(to: CGPoint(x: centerX, y: centerY - 12))
                },
                with: .color(.green),
                lineWidth: 2
            )
            
            // Draw LIDAR points
            let validPoints = scanData.validPoints()
            for point in validPoints {
                let x = centerX + CGFloat(point.distance * cos(point.angle - .pi / 2)) * scale
                let y = centerY - CGFloat(point.distance * sin(point.angle - .pi / 2)) * scale
                
                let normalizedDistance = min(point.distance / maxRange, 1.0)
                let hue = normalizedDistance * 120 // 0 (red) to 120 (green)
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                    with: .color(Color(hue: hue / 360, saturation: 1.0, brightness: 1.0))
                )
            }
        }
    }
}

struct ConnectionIndicator: View {
    let isConnected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(isConnected ? "LIDAR" : "OFFLINE")
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
    LidarVisualizationView(ros2Manager: ROS2WebSocketManager())
        .frame(width: 300, height: 300)
}

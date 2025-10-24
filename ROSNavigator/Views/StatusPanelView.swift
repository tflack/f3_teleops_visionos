//
//  StatusPanelView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

struct StatusPanelView: View {
    @Environment(AppModel.self) var appModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(connectionColor)
                Text("F3 Teleop Console")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            // Robot info header
            HStack(spacing: 8) {
                Image("robot_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                Text("Connected Robot")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // Connection status
            HStack {
                Circle()
                    .fill(connectionColor)
                    .frame(width: 8, height: 8)
                Text(connectionStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Robot status
            HStack {
                Image(systemName: "robot")
                    .foregroundColor(robotStatusColor)
                Text("\(appModel.selectedRobot.name)")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(robotStatusText)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(robotStatusColor.opacity(0.2), in: Capsule())
                    .foregroundColor(robotStatusColor)
            }
            
            // Robot IP
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.secondary)
                Text("IP: \(appModel.selectedRobot.ipAddress)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Available cameras
            if !appModel.selectedRobot.cameras.isEmpty {
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.secondary)
                    Text("Cameras: \(appModel.selectedRobot.cameras.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Stream health
            HStack {
                Image(systemName: "video")
                    .foregroundColor(streamHealthColor)
                Text("Stream Health:")
                    .font(.caption)
                Text(appModel.streamHealth)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(streamHealthColor)
            }
            
            // Camera count
            if appModel.cameraCount > 0 {
                HStack {
                    Image(systemName: "camera")
                        .foregroundColor(.secondary)
                    Text("\(appModel.cameraCount) cameras active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    private var connectionColor: Color {
        switch appModel.ros2ConnectionState {
        case .connected:
            return .green
        case .connecting:
            return .orange
        case .disconnected:
            return .red
        case .error:
            return .red
        }
    }
    
    private var connectionStatusText: String {
        switch appModel.ros2ConnectionState {
        case .connected:
            return "Connected to \(appModel.selectedRobot.ipAddress)"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    private var robotStatusColor: Color {
        switch appModel.robotStatus {
        case .online:
            return .green
        case .offline:
            return .red
        case .event:
            return .orange
        }
    }
    
    private var robotStatusText: String {
        switch appModel.robotStatus {
        case .online:
            return "ONLINE"
        case .offline:
            return "OFFLINE"
        case .event:
            return "EVENT"
        }
    }
    
    private var streamHealthColor: Color {
        switch appModel.streamHealth {
        case "Nominal":
            return .green
        case "Degraded":
            return .orange
        default:
            return .red
        }
    }
}

#Preview {
    StatusPanelView()
        .environment(AppModel())
}

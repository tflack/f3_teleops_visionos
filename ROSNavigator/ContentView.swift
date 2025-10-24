//
//  ContentView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @State private var showVideoTest = false
    @State private var hasSelectedRobot = false
    
    // Camera position state
    @State private var rgbCameraPosition = CGPoint(x: 200, y: 300)
    @State private var heatmapCameraPosition = CGPoint(x: 600, y: 300)

    var body: some View {
        if appModel.immersiveSpaceState == .closed {
            VStack(spacing: 20) {
            Text("ROSNavigator")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text(hasSelectedRobot ? "Selected: \(appModel.selectedRobot.displayName)" : "Select a robot to connect")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Robot selection list - only show if no robot selected
            if !hasSelectedRobot {
                VStack(spacing: 12) {
                    ForEach(AppModel.Robot.allCases) { robot in
                        RobotSelectionCard(
                            robot: robot,
                            isSelected: appModel.selectedRobot.id == robot.id,
                            onSelect: {
                                appModel.selectedRobot = robot
                                hasSelectedRobot = true
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Show camera streams when a robot is selected
            if hasSelectedRobot {
                VStack(spacing: 16) {
                    HStack {
                        Button(action: {
                            hasSelectedRobot = false
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left")
                                Text("Back to Robot List")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.blue)
                            .cornerRadius(10)
                        }
                        
                        Spacer()
                        
                        Text("Camera Feeds")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button("Reset Cameras") {
                                rgbCameraPosition = CGPoint(x: 200, y: 300)
                                heatmapCameraPosition = CGPoint(x: 600, y: 300)
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.orange.opacity(0.1))
                            .cornerRadius(8)
                            
                            Button("Change Robot") {
                                hasSelectedRobot = false
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top)
                    
                    // Draggable camera feeds
                    ZStack {
                        // Background for camera feeds area
                        Rectangle()
                            .fill(.clear)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // RGB Camera Feed - Draggable
                        DraggableCameraFeedView(
                            ros2Manager: ROS2WebSocketManager.shared,
                            cameraType: .rgb,
                            position: $rgbCameraPosition
                        )
                        
                        // Heatmap Camera Feed - Draggable
                        DraggableCameraFeedView(
                            ros2Manager: ROS2WebSocketManager.shared,
                            cameraType: .heatmap,
                            position: $heatmapCameraPosition
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Prominent back button
                    Button(action: {
                        hasSelectedRobot = false
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.left.circle.fill")
                                .font(.title2)
                            Text("Back to Robot Selection")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            }
            
                        Spacer()

                        // Test button
                        Button {
                            showVideoTest = true
                        } label: {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver")
                                Text("Test Video Stream")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .padding(.horizontal)

                        // Connect button
            Button {
                Task { @MainActor in
                    appModel.immersiveSpaceState = .inTransition
                    switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                        case .opened:
                            break
                        case .userCancelled, .error:
                            fallthrough
                        @unknown default:
                            appModel.immersiveSpaceState = .closed
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Connect to \(appModel.selectedRobot.displayName)")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
            }
            .buttonStyle(PlainButtonStyle())
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(appModel.immersiveSpaceState == .inTransition ? Color.gray : Color.blue)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .disabled(appModel.immersiveSpaceState == .inTransition)
            .padding(.horizontal)
            .padding(.bottom)
        }
                    .onAppear {
                        // Start checking robot connections asynchronously
                        appModel.checkRobotConnections()
                    }
                    .sheet(isPresented: $showVideoTest) {
                        SimpleMJPEGTestView()
                    }
        } else {
            // Show minimal view when immersive space is open
            VStack {
                Text("Immersive View Active")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("Camera feeds and controls are now in the immersive space")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}

struct RobotSelectionCard: View {
    let robot: AppModel.Robot
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(AppModel.self) private var appModel
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Robot image
                Image("robot_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                    )
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(robot.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Connection status indicator
                        Circle()
                            .fill(connectionStatusColor)
                            .frame(width: 8, height: 8)
                    }
                    
                    Text("IP: \(robot.ipAddress)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !robot.cameras.isEmpty {
                        Text("Cameras: \(robot.cameras.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var connectionStatusColor: Color {
        let status = appModel.getRobotConnectionStatus(robot.id)
        return status.color
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}

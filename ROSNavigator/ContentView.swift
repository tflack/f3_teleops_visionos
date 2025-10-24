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

    var body: some View {
        VStack(spacing: 20) {
            Text("ROSNavigator")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Text("Select a robot to connect")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Robot selection list
            VStack(spacing: 12) {
                ForEach(AppModel.Robot.allCases) { robot in
                    RobotSelectionCard(
                        robot: robot,
                        isSelected: appModel.selectedRobot.id == robot.id,
                        onSelect: {
                            appModel.selectedRobot = robot
                        }
                    )
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
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
    }
}

struct RobotSelectionCard: View {
    let robot: AppModel.Robot
    let isSelected: Bool
    let onSelect: () -> Void
    
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
                    Text(robot.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
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
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}

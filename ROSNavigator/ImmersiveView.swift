//
//  ImmersiveView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import RealityKit
import RealityKitContent
import Combine

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    @State private var ros2Manager: ROS2WebSocketManager
    
    init() {
        print("🌐 ImmersiveView init called")
        // Initialize with default robot, will be updated in onAppear
        _ros2Manager = State(initialValue: ROS2WebSocketManager(serverIP: AppModel.Robot.alpha.ipAddress))
    }

    var body: some View {
        RealityView { content in
            print("🌐 ImmersiveView RealityView setup started")
            // Add the initial RealityKit content
            do {
                // Try to load from RealityKitContent bundle using the proper module bundle
                let immersiveContentEntity = try await Entity(named: "Immersive", in: realityKitContentBundle)
                print("🌐 Successfully loaded immersive content entity from RealityKitContent bundle")
                content.add(immersiveContentEntity)
            } catch {
                print("🌐 Failed to load immersive content entity: \(error)")
                // Create a simple fallback entity
                let fallbackEntity = Entity()
                fallbackEntity.name = "FallbackContent"
                print("🌐 Created fallback entity")
                content.add(fallbackEntity)
            }
        } update: { content in
            print("🌐 ImmersiveView RealityView update called")
            // Update content if needed
        }
        .overlay(alignment: .center) {
            VStack(spacing: 20) {
                Text("Immersive View Active")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(20)
                    .background(.blue.opacity(0.9))
                    .cornerRadius(20)
                
                Text("Camera feeds are now displayed in the main content view")
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(20)
            .onAppear {
                print("🌐 Immersive view overlay appeared!")
            }
        }
        .onAppear {
            print("🌐 ImmersiveView onAppear called")
            setupROS2Connection()
        }
        .onDisappear {
            ros2Manager.disconnect()
        }
    }
    
    private func setupROS2Connection() {
        print("🔌 Setting up ROS2 connection for robot: \(appModel.selectedRobot.name)")
        print("🔌 Robot IP: \(appModel.selectedRobot.ipAddress)")
        
        // Reinitialize ROS2WebSocketManager with selected robot's IP
        ros2Manager = ROS2WebSocketManager(serverIP: appModel.selectedRobot.ipAddress)
        
        // Connect to ROS2 WebSocket
        print("🔌 Initiating WebSocket connection...")
        ros2Manager.connect()
        
        // Subscribe to connection state changes
        Task {
            for await state in ros2Manager.$connectionState.values {
                print("🔌 ROS2 connection state changed: \(state)")
                appModel.updateROS2ConnectionState(state)
            }
        }
    }
}

#Preview(immersionStyle: .progressive) {
    ImmersiveView()
        .environment(AppModel())
}

//
//  ImmersiveDraggableCameraView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/24/25.
//

import SwiftUI
import RealityKit

struct ImmersiveDraggableCameraView: View {
    let ros2Manager: ROS2WebSocketManager
    let cameraType: VideoStreamManager.CameraType
    @Binding var position: CGPoint
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    
    private var cameraTitle: String {
        switch cameraType {
        case .rgb:
            return "RGB Camera"
        case .heatmap:
            return "Heatmap Camera"
        case .ir:
            return "IR Camera"
        }
    }
    
    private var cameraColor: Color {
        switch cameraType {
        case .rgb:
            return .green
        case .heatmap:
            return .orange
        case .ir:
            return .purple
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Camera title bar with drag handle
            HStack {
                Image(systemName: "grip.horizontal")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
                
                Text(cameraTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Connection status indicator
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(cameraColor.opacity(0.8))
            .cornerRadius(8)
            
            // Camera feed content
            CameraFeedView(ros2Manager: ros2Manager, selectedCamera: .constant(cameraType))
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
        }
        .frame(width: 320, height: 200)
        .background(.black.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
        .shadow(
            color: isDragging ? .blue.opacity(0.6) : .black.opacity(0.4),
            radius: isDragging ? 15 : 8,
            x: 0,
            y: isDragging ? 8 : 4
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .position(
            x: position.x + dragOffset.width,
            y: position.y + dragOffset.height
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    // Update the position with the final drag offset
                    position = CGPoint(
                        x: position.x + value.translation.width,
                        y: position.y + value.translation.height
                    )
                    dragOffset = .zero
                }
        )
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        ImmersiveDraggableCameraView(
            ros2Manager: ROS2WebSocketManager.shared,
            cameraType: .rgb,
            position: .constant(CGPoint(x: 200, y: 200))
        )
    }
}

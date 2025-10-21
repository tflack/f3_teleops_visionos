//
//  AlertsPanelView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

struct AlertsPanelView: View {
    @Environment(AppModel.self) var appModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with toggle
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(hasAlerts ? .orange : .secondary)
                Text("Alerts")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    // Emergency stop alert
                    if appModel.emergencyStop {
                        AlertRow(
                            icon: "stop.circle.fill",
                            message: "Emergency Stop Active",
                            color: .red,
                            isCritical: true
                        )
                    }
                    
                    // Obstacle warning
                    if appModel.obstacleWarning && !appModel.safetyOverride {
                        AlertRow(
                            icon: "exclamationmark.triangle.fill",
                            message: "Obstacle Detected - Speed Reduced",
                            color: .orange,
                            isCritical: false
                        )
                    }
                    
                    // Safety override
                    if appModel.safetyOverride {
                        AlertRow(
                            icon: "shield.slash.fill",
                            message: "Safety Override Active",
                            color: .red,
                            isCritical: true
                        )
                    }
                    
                    // Connection issues
                    if !appModel.isROS2Connected {
                        AlertRow(
                            icon: "wifi.slash",
                            message: "ROS2 Connection Lost",
                            color: .red,
                            isCritical: true
                        )
                    }
                    
                    // Stream issues
                    if appModel.streamHealth != "Nominal" {
                        AlertRow(
                            icon: "video.slash",
                            message: "Stream Health: \(appModel.streamHealth)",
                            color: .orange,
                            isCritical: false
                        )
                    }
                    
                    // No alerts
                    if !hasAlerts {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("All systems nominal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var hasAlerts: Bool {
        return appModel.emergencyStop ||
               (appModel.obstacleWarning && !appModel.safetyOverride) ||
               appModel.safetyOverride ||
               !appModel.isROS2Connected ||
               appModel.streamHealth != "Nominal"
    }
}

struct AlertRow: View {
    let icon: String
    let message: String
    let color: Color
    let isCritical: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            Text(message)
                .font(.caption)
                .foregroundColor(isCritical ? .primary : .secondary)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    AlertsPanelView()
        .environment(AppModel())
}

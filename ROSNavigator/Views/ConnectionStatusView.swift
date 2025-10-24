//
//  ConnectionStatusView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

struct ConnectionStatusView: View {
    @ObservedObject var videoStreamManager: VideoStreamManager
    @State private var showingDiagnostics = false
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Connection status indicator
                Circle()
                    .fill(connectionStatusColor)
                    .frame(width: 12, height: 12)
                
                Text(connectionStatusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Retry button if there's an error
                if videoStreamManager.connectionError != nil && !videoStreamManager.isRetrying {
                    Button("Retry") {
                        videoStreamManager.retryConnection()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                
                // Diagnostics button
                Button("Diagnose") {
                    showingDiagnostics = true
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
            // Error message if present
            if let error = videoStreamManager.connectionError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }
            
            // Retry status
            if videoStreamManager.isRetrying {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Retrying connection...")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .sheet(isPresented: $showingDiagnostics) {
            VideoTestView()
        }
    }
    
    private var connectionStatusColor: Color {
        if videoStreamManager.isConnected {
            return .green
        } else if videoStreamManager.isRetrying {
            return .orange
        } else if videoStreamManager.connectionError != nil {
            return .red
        } else {
            return .gray
        }
    }
    
    private var connectionStatusText: String {
        if videoStreamManager.isConnected {
            return "Video Stream Connected"
        } else if videoStreamManager.isRetrying {
            return "Retrying Connection..."
        } else if videoStreamManager.connectionError != nil {
            return "Connection Failed"
        } else {
            return "Not Connected"
        }
    }
}

#Preview {
    VStack {
        ConnectionStatusView(videoStreamManager: VideoStreamManager())
        Spacer()
    }
    .padding()
}

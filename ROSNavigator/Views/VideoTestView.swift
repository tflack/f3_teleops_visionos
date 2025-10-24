//
//  VideoTestView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

struct VideoTestView: View {
    @StateObject private var videoManager = VideoStreamManager()
    @State private var selectedCamera: VideoStreamManager.CameraType = .rgb
    @State private var showDebugInfo = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack {
                    Text("Video Stream Test")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("WebView-based MJPEG streaming")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Camera selection
                Picker("Camera", selection: $selectedCamera) {
                    Text("RGB Camera").tag(VideoStreamManager.CameraType.rgb)
                    Text("Heatmap").tag(VideoStreamManager.CameraType.heatmap)
                    Text("IR Camera").tag(VideoStreamManager.CameraType.ir)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Video display
                VStack {
                    if let streamURL = videoManager.getStreamURL(for: selectedCamera) {
                        SimpleVideoView(streamURL: streamURL)
                            .frame(height: 300)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 300)
                            .overlay(
                                VStack {
                                    Image(systemName: "video.slash")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("No stream URL available")
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                }
                .padding(.horizontal)
                
                // Connection status
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(videoManager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(videoManager.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    if let error = videoManager.connectionError {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                    
                    if videoManager.isRetrying {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Retrying connection...")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Control buttons
                HStack(spacing: 16) {
                    Button("Start Streams") {
                        videoManager.startStreams()
                    }
                    .buttonStyle(.bordered)
                    .disabled(videoManager.isRetrying)
                    
                    Button("Stop Streams") {
                        videoManager.stopStreams()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Retry") {
                        videoManager.retryConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(videoManager.isRetrying)
                }
                .padding(.horizontal)
                
                // Debug info toggle
                Button(showDebugInfo ? "Hide Debug Info" : "Show Debug Info") {
                    showDebugInfo.toggle()
                }
                .font(.caption)
                .foregroundColor(.blue)
                
                // Debug information
                if showDebugInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug Information")
                            .font(.caption)
                            .fontWeight(.bold)
                        
                        Group {
                            Text("Server IP: \(videoManager.serverIP)")
                            Text("RGB URL: \(videoManager.rgbStreamURL?.absoluteString ?? "nil")")
                            Text("Heatmap URL: \(videoManager.heatmapStreamURL?.absoluteString ?? "nil")")
                            Text("IR URL: \(videoManager.irStreamURL?.absoluteString ?? "nil")")
                            Text("Selected Camera: \(selectedCamera)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Video Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Auto-start streams when view appears
            videoManager.startStreams()
        }
    }
}

#Preview {
    VideoTestView()
}

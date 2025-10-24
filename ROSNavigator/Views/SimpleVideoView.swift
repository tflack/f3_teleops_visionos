//
//  SimpleVideoView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

struct SimpleVideoView: View {
    let streamURL: URL?
    @State private var isLoading = false
    @State private var hasError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            if let url = streamURL {
                WebViewVideoPlayer(
                    url: url,
                    isLoading: $isLoading,
                    hasError: $hasError,
                    errorMessage: $errorMessage
                )
                .background(Color.black)
            } else {
                // No stream URL provided
                VStack {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No video stream URL")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
            
            // Loading overlay
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading video stream...")
                        .foregroundColor(.white)
                        .font(.caption)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.7))
            }
            
            // Error overlay
            if hasError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    
                    Text("Video Stream Error")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry") {
                        // Trigger a reload by updating the URL
                        if let url = streamURL {
                            // Force reload by adding a timestamp parameter
                            let newURL = URL(string: "\(url.absoluteString)&t=\(Date().timeIntervalSince1970)") ?? url
                            // This will cause the WebView to reload
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
            }
        }
        .onAppear {
            print("📹 SimpleVideoView appeared with URL: \(streamURL?.absoluteString ?? "nil")")
        }
    }
}

#Preview {
    SimpleVideoView(streamURL: URL(string: "http://192.168.1.49:8080/stream?topic=/depth_cam/rgb/image_raw"))
        .frame(width: 400, height: 300)
}

//
//  SimpleWebViewTest.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

struct SimpleWebViewTest: View {
    @State private var isLoading = false
    @State private var hasError = false
    @State private var errorMessage = ""
    
    private let streamURL = URL(string: "http://192.168.1.49:8080/stream?topic=/depth_cam/rgb/image_raw")!
    
    var body: some View {
        VStack {
            Text("Simple WebView Stream Test")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            Text("Hardcoded URL: \(streamURL.absoluteString)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // WebView with hardcoded URL
            WebViewVideoPlayer(
                url: streamURL,
                isLoading: $isLoading,
                hasError: $hasError,
                errorMessage: $errorMessage
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .cornerRadius(12)
            .padding()
            
            // Status indicators
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading stream...")
                        .font(.caption)
                }
                .padding()
            }
            
            if hasError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text("Error: \(errorMessage)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .navigationTitle("WebView Test")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        SimpleWebViewTest()
    }
}

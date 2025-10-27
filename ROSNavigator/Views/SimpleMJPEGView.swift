//
//  SimpleMJPEGView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import WebKit

struct SimpleMJPEGView: UIViewRepresentable {
    let streamURL: URL
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var errorMessage: String
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if the URL has changed
        if webView.url?.absoluteString != streamURL.absoluteString {
            // Create HTML that mimics the f3_teleops approach
            let html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                    body {
                        margin: 0;
                        padding: 0;
                        background-color: black;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                        height: 100vh;
                        overflow: hidden;
                    }
                    .stream-container {
                        width: 100%;
                        height: 100%;
                        display: flex;
                        justify-content: center;
                        align-items: center;
                    }
                    .stream-image {
                        width: 100%;
                        height: 100%;
                        object-fit: cover;
                        background-color: black;
                    }
                    .error-message {
                        color: white;
                        text-align: center;
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        padding: 20px;
                    }
                    .loading-message {
                        color: white;
                        text-align: center;
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        padding: 20px;
                    }
                </style>
            </head>
            <body>
                <div class="stream-container">
                    <img 
                        id="streamImage" 
                        class="stream-image" 
                        src="\(streamURL.absoluteString)" 
                        alt="MJPEG Stream"
                        loading="eager"
                        onload="handleImageLoad()"
                        onerror="handleImageError()"
                    />
                </div>
                
                <script>
                    function handleImageLoad() {
                        console.log('✅ MJPEG stream loaded successfully');
                        window.webkit.messageHandlers.streamStatus.postMessage({
                            type: 'loaded',
                            message: 'Stream loaded successfully'
                        });
                    }
                    
                    function handleImageError() {
                        console.error('❌ MJPEG stream failed to load');
                        window.webkit.messageHandlers.streamStatus.postMessage({
                            type: 'error',
                            message: 'Failed to load stream'
                        });
                    }
                    
                    // Add periodic refresh to keep stream alive
                    setInterval(function() {
                        const img = document.getElementById('streamImage');
                        if (img) {
                            const currentSrc = img.src;
                            img.src = '';
                            img.src = currentSrc;
                        }
                    }, 30000); // Refresh every 30 seconds
                </script>
            </body>
            </html>
            """
            
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: SimpleMJPEGView
        private var isHandlerAdded = false
        
        init(_ parent: SimpleMJPEGView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Add message handler for JavaScript communication only if not already added
            if !isHandlerAdded {
                webView.configuration.userContentController.add(self, name: "streamStatus")
                isHandlerAdded = true
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Remove existing handler before loading new content
            if isHandlerAdded {
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "streamStatus")
                isHandlerAdded = false
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            if message.name == "streamStatus" {
                DispatchQueue.main.async {
                    if let type = body["type"] as? String {
                        switch type {
                        case "loaded":
                            self.parent.isLoading = false
                            self.parent.hasError = false
                            self.parent.errorMessage = ""
                        case "error":
                            self.parent.isLoading = false
                            self.parent.hasError = true
                            self.parent.errorMessage = body["message"] as? String ?? "Unknown error"
                        default:
                            break
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
                self.parent.errorMessage = error.localizedDescription
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
                self.parent.errorMessage = error.localizedDescription
            }
        }
        
        deinit {
            // Clean up message handler if still added
            if isHandlerAdded {
                // Note: We can't access the webView here, but the handler will be cleaned up
                // when the webView is deallocated
                isHandlerAdded = false
            }
        }
    }
}

struct SimpleMJPEGTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var hasError = false
    @State private var errorMessage = ""
    @State private var selectedCamera: CameraType = .rgb
    
    enum CameraType: String, CaseIterable {
        case rgb = "RGB Camera"
        case heatmap = "Heatmap Camera"
        
        var topic: String {
            switch self {
            case .rgb:
                return "/object_detection_overlay/image_raw"
            case .heatmap:
                return "/heatmap_3d/image_raw"
            }
        }
        
        var streamURL: URL {
            return URL(string: "http://192.168.1.49:8080/stream?topic=\(topic)")!
        }
    }
    
    var body: some View {
        VStack {
            // Header with close button
            HStack {
                Text("MJPEG Stream Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            
            // Camera selection picker
            Picker("Camera", selection: $selectedCamera) {
                ForEach(CameraType.allCases, id: \.self) { camera in
                    Text(camera.rawValue).tag(camera)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            Text("URL: \(selectedCamera.streamURL.absoluteString)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // MJPEG stream using direct img tag approach
            SimpleMJPEGView(
                streamURL: selectedCamera.streamURL,
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
                    Text("Loading \(selectedCamera.rawValue)...")
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
        .navigationTitle("MJPEG Test")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        SimpleMJPEGTestView()
    }
}

//
//  WebViewVideoPlayer.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI
import WebKit

struct WebViewVideoPlayer: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    @Binding var errorMessage: String
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        
        // Add message handler for JavaScript communication
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "videoStatus")
        configuration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor.black
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Create HTML content that embeds the MJPEG stream
        let htmlContent = """
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
                .video-container {
                    position: relative;
                    width: 100%;
                    height: 100%;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                }
                img {
                    max-width: 100%;
                    max-height: 100%;
                    object-fit: contain;
                    background-color: black;
                }
                .error-message {
                    color: white;
                    text-align: center;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 16px;
                    padding: 20px;
                }
                .loading {
                    color: white;
                    text-align: center;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    font-size: 16px;
                }
            </style>
        </head>
        <body>
            <div class="video-container">
                <img id="videoStream" 
                     src="\(url.absoluteString)" 
                     alt="Video Stream"
                     onload="handleLoad()"
                     onerror="handleError()"
                     style="display: none;">
                <div id="loading" class="loading">Loading video stream...</div>
                <div id="error" class="error-message" style="display: none;"></div>
            </div>
            
            <script>
                function handleLoad() {
                    console.log('Video stream loaded successfully');
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('videoStream').style.display = 'block';
                    document.getElementById('error').style.display = 'none';
                    
                    // Notify Swift that loading is complete
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.videoStatus) {
                        window.webkit.messageHandlers.videoStatus.postMessage({
                            type: 'loaded',
                            url: '\(url.absoluteString)'
                        });
                    }
                }
                
                function handleError() {
                    console.error('Failed to load video stream');
                    document.getElementById('loading').style.display = 'none';
                    document.getElementById('videoStream').style.display = 'none';
                    document.getElementById('error').style.display = 'block';
                    document.getElementById('error').textContent = 'Failed to load video stream from \(url.absoluteString)';
                    
                    // Notify Swift that there was an error
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.videoStatus) {
                        window.webkit.messageHandlers.videoStatus.postMessage({
                            type: 'error',
                            url: '\(url.absoluteString)',
                            message: 'Failed to load video stream'
                        });
                    }
                }
                
                // Auto-refresh the stream every 30 seconds to handle connection issues
                setInterval(function() {
                    const img = document.getElementById('videoStream');
                    if (img && img.style.display !== 'none') {
                        const currentSrc = img.src;
                        img.src = '';
                        setTimeout(function() {
                            img.src = currentSrc + '&t=' + Date.now();
                        }, 100);
                    }
                }, 30000);
                
                // Initial load
                console.log('Loading video stream from: \(url.absoluteString)');
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: WebViewVideoPlayer
        
        init(_ parent: WebViewVideoPlayer) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            if message.name == "videoStatus" {
                DispatchQueue.main.async {
                    if let type = body["type"] as? String {
                        switch type {
                        case "loaded":
                            self.parent.isLoading = false
                            self.parent.hasError = false
                            self.parent.errorMessage = ""
                            print("📹 WebView: Video stream loaded successfully")
                        case "error":
                            self.parent.isLoading = false
                            self.parent.hasError = true
                            self.parent.errorMessage = body["message"] as? String ?? "Unknown error"
                            print("❌ WebView: Video stream error - \(self.parent.errorMessage)")
                        default:
                            break
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.hasError = false
                self.parent.errorMessage = ""
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
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
    }
}

#Preview {
    WebViewVideoPlayer(
        url: URL(string: "http://192.168.1.49:8080/stream?topic=/depth_cam/rgb/image_raw")!,
        isLoading: .constant(false),
        hasError: .constant(false),
        errorMessage: .constant("")
    )
    .frame(width: 400, height: 300)
}

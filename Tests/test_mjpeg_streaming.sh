#!/bin/bash

# MJPEG Streaming Diagnostic Script
# Run this on your robot to test MJPEG streaming setup

echo "🔍 MJPEG Streaming Diagnostic Script"
echo "====================================="
echo ""

# Check if web_video_server is running
echo "1. Checking if web_video_server is running..."
if pgrep -f "web_video_server" > /dev/null; then
    echo "✅ web_video_server is running"
else
    echo "❌ web_video_server is NOT running"
    echo "💡 Start it with: ros2 run web_video_server web_video_server"
    echo ""
fi

# Check available topics
echo "2. Checking available image topics..."
echo "Available topics containing 'image':"
ros2 topic list | grep -i image || echo "❌ No image topics found"
echo ""

# Check specific topic
echo "3. Checking /depth_cam/rgb/image_raw topic..."
if ros2 topic list | grep -q "/depth_cam/rgb/image_raw"; then
    echo "✅ Topic /depth_cam/rgb/image_raw exists"
    
    # Check if topic is publishing
    echo "Checking if topic is publishing data..."
    timeout 5 ros2 topic echo /depth_cam/rgb/image_raw --once > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Topic is publishing data"
    else
        echo "❌ Topic is not publishing data (timeout after 5 seconds)"
        echo "💡 Check if camera is connected and publishing"
    fi
else
    echo "❌ Topic /depth_cam/rgb/image_raw does NOT exist"
    echo "💡 Check camera node and topic names"
fi
echo ""

# Test web_video_server endpoint
echo "4. Testing web_video_server HTTP endpoint..."
if curl -s --connect-timeout 5 http://localhost:8080 > /dev/null; then
    echo "✅ web_video_server HTTP endpoint is accessible"
else
    echo "❌ web_video_server HTTP endpoint is NOT accessible"
    echo "💡 Check if web_video_server is running on port 8080"
fi
echo ""

# Test MJPEG stream endpoint
echo "5. Testing MJPEG stream endpoint..."
if curl -s --connect-timeout 10 --max-time 15 "http://localhost:8080/stream?topic=/depth_cam/rgb/image_raw" > /dev/null; then
    echo "✅ MJPEG stream endpoint is accessible"
else
    echo "❌ MJPEG stream endpoint is NOT accessible"
    echo "💡 This is likely the cause of the timeout error"
fi
echo ""

# Check network connectivity
echo "6. Checking network connectivity..."
echo "Robot IP addresses:"
ip addr show | grep "inet " | grep -v "127.0.0.1" || echo "❌ No network interfaces found"
echo ""

# Check if port 8080 is listening
echo "7. Checking if port 8080 is listening..."
if netstat -tlnp 2>/dev/null | grep ":8080" > /dev/null; then
    echo "✅ Port 8080 is listening"
    netstat -tlnp 2>/dev/null | grep ":8080"
else
    echo "❌ Port 8080 is NOT listening"
    echo "💡 web_video_server may not be running or using different port"
fi
echo ""

# System resource check
echo "8. Checking system resources..."
echo "CPU usage:"
top -bn1 | grep "Cpu(s)" || echo "Could not get CPU info"
echo "Memory usage:"
free -h || echo "Could not get memory info"
echo ""

# ROS2 node status
echo "9. Checking ROS2 nodes..."
echo "Active ROS2 nodes:"
ros2 node list || echo "❌ No ROS2 nodes found"
echo ""

echo "🔧 Troubleshooting Summary:"
echo "=========================="
echo "If you're getting timeout errors:"
echo "1. Make sure web_video_server is running: ros2 run web_video_server web_video_server"
echo "2. Check if camera topic exists: ros2 topic list | grep image"
echo "3. Verify camera is publishing: ros2 topic echo /depth_cam/rgb/image_raw --once"
echo "4. Test local MJPEG stream: curl -v http://localhost:8080/stream?topic=/depth_cam/rgb/image_raw"
echo "5. Check robot IP address and network connectivity"
echo ""
echo "Common solutions:"
echo "- Restart web_video_server: pkill web_video_server && ros2 run web_video_server web_video_server"
echo "- Check camera node: ros2 node list | grep camera"
echo "- Verify topic name: ros2 topic info /depth_cam/rgb/image_raw"
echo ""

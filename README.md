# ROSNavigator - VisionOS Teleoperation Interface

A native VisionOS application that provides immersive teleoperation capabilities for ROS2-based robots, featuring spatial computing with floating 3D panels, hand gesture controls, and Bluetooth gamepad support.

## 🚀 Features

### Core Functionality
- **Immersive Spatial Interface**: Floating 3D panels arranged around the user in virtual space
- **Dual Input Support**: Hand gestures and Bluetooth gamepad controls
- **Real-time Robot Control**: Movement, rotation, and arm manipulation
- **Multi-camera Streaming**: RGB, Heatmap, and IR camera feeds with overlays
- **Advanced Visualizations**: LIDAR, SLAM map, and 3D point cloud rendering
- **Object Detection**: Real-time object recognition with pick actions
- **Safety Systems**: Emergency stop, obstacle warnings, and safety override

### Technical Features
- **ROS2 Integration**: WebSocket bridge with native DDS alternative
- **Performance Optimization**: Auto-optimization based on system performance
- **Error Handling**: Comprehensive error recovery and user feedback
- **Accessibility**: Full VoiceOver support, haptic feedback, and audio cues
- **Tutorial System**: Interactive onboarding for new users
- **Debug Console**: Real-time monitoring and diagnostics

## 🏗️ Architecture

### Core Components

#### ROS2 Communication
- **`ROS2WebSocketManager`**: Primary WebSocket connection to rosbridge_server
- **`ROS2NativeBridge`**: Alternative native DDS-based ROS2 client
- **`ROS2Messages/`**: Swift structs for all ROS2 message types

#### Input Management
- **`GamepadManager`**: Bluetooth gamepad input handling
- **`InputCoordinator`**: Merges hand gesture and gamepad inputs
- **`RobotControlManager`**: Translates inputs to ROS2 commands

#### User Interface
- **`SpatialTeleopView`**: Main immersive interface with floating panels
- **`WindowCoordinator`**: 3D panel positioning and management
- **`VirtualJoystickView`**: Hand gesture-based joystick controls

#### Visualization
- **`LidarVisualizationView`**: Real-time 2D LIDAR scan rendering
- **`SLAMMapView`**: Occupancy grid visualization with robot pose
- **`PointCloudView`**: 3D point cloud rendering with gesture controls
- **`CameraFeedView`**: Multi-stream video display with overlays

#### System Management
- **`ErrorHandlingManager`**: Comprehensive error recovery system
- **`PerformanceManager`**: Performance monitoring and optimization
- **`UserExperienceManager`**: Tutorials, accessibility, and user preferences

## 📱 User Interface

### Spatial Layout
The interface consists of floating panels arranged in 3D space:

- **Center**: Main camera feed (RGB with object detection overlays)
- **Left**: LIDAR and SLAM map visualizations
- **Right**: 3D point cloud viewer
- **Bottom**: Control panel with virtual joysticks
- **Top**: Status bar and alerts panel
- **Bottom Right**: Debug console

### Control Methods

#### Hand Gestures
- **Virtual Joysticks**: Drag to control robot movement and rotation
- **Panel Interaction**: Move, resize, and organize panels in 3D space
- **Point Cloud Navigation**: Rotate and zoom 3D point clouds

#### Gamepad Controls
- **Left Stick**: Robot movement (forward/backward, strafe)
- **Right Stick**: Robot rotation or arm control (mode-dependent)
- **Triggers**: Speed control and gripper operation
- **Buttons**: Mode switching, emergency stop, and quick actions

## 🔧 Setup and Configuration

### Prerequisites
- **visionOS 1.0+**
- **Xcode 15.0+**
- **Swift 5.9+**
- **ROS2 robot with rosbridge_server running**

### Robot Configuration
The app connects to a robot at `192.168.1.49` with the following services:

- **WebSocket**: `ws://192.168.1.49:9090` (rosbridge_server)
- **Video Streams**: `http://192.168.1.49:8080` (web_video_server)
- **ROS2 Topics**: Standard ROS2 topics for control and data

### Required ROS2 Topics
```
/cmd_vel_user          # Robot velocity commands
/servo_controller      # Arm control commands
/scan                  # LIDAR data
/map                   # SLAM occupancy grid
/cloud_map             # 3D point cloud
/detected_objects      # Object detection results
/obstacle_warning      # Safety warnings
/execute_action        # Action execution
```

### Required ROS2 Services
```
/list_available_actions    # Get available robot actions
/slam_toolbox/clear_queue  # Clear SLAM queue
```

## 🎮 Usage

### First Launch
1. Launch the app on VisionOS
2. Complete the interactive tutorial
3. Connect to your robot network
4. Start teleoperation

### Basic Controls
1. **Movement**: Use left virtual joystick or gamepad left stick
2. **Rotation**: Use right virtual joystick or gamepad right stick
3. **Speed Control**: Adjust speed slider or use gamepad triggers
4. **Mode Switching**: Toggle between manual and arm control modes
5. **Emergency Stop**: Press the red emergency stop button

### Advanced Features
- **Object Picking**: Tap detected objects to execute pick actions
- **Panel Management**: Move and resize panels in 3D space
- **Performance Monitoring**: View real-time performance metrics
- **Error Recovery**: Automatic error detection and recovery

## 🛠️ Development

### Project Structure
```
ROSNavigator/
├── ROSNavigator/
│   ├── AppModel.swift                 # App-wide state management
│   ├── SpatialTeleopView.swift        # Main immersive interface
│   ├── ROS2WebSocketManager.swift     # WebSocket ROS2 bridge
│   ├── ROS2NativeBridge.swift         # Native ROS2 client
│   ├── GamepadManager.swift           # Gamepad input handling
│   ├── InputCoordinator.swift         # Input coordination
│   ├── RobotControlManager.swift      # Robot control logic
│   ├── ActionManager.swift            # Action execution
│   ├── WindowCoordinator.swift        # 3D panel management
│   ├── ErrorHandlingManager.swift     # Error recovery
│   ├── PerformanceManager.swift       # Performance optimization
│   ├── UserExperienceManager.swift    # UX and accessibility
│   ├── VideoStreamManager.swift       # Video stream handling
│   ├── ROS2Messages/                  # ROS2 message types
│   ├── Views/                         # UI components
│   └── Controls/                      # Control components
└── Packages/
    └── RealityKitContent/             # 3D assets
```

### Key Technologies
- **SwiftUI**: Modern declarative UI framework
- **RealityKit**: 3D rendering and spatial computing
- **Combine**: Reactive programming and data flow
- **GameController**: Bluetooth gamepad integration
- **AVFoundation**: Video stream handling
- **CoreGraphics**: 2D visualization rendering

### Building and Running
1. Open `ROSNavigator.xcodeproj` in Xcode
2. Select your VisionOS device or simulator
3. Build and run the project
4. Ensure your robot is running and accessible

## 🔍 Debugging and Monitoring

### Debug Console
The debug console provides real-time monitoring of:
- **Messages**: ROS2 WebSocket communication log
- **Performance**: FPS, memory usage, CPU usage, network latency
- **Connections**: Status of all system connections
- **Gamepad**: Real-time gamepad input monitoring

### Error Handling
The app includes comprehensive error handling:
- **Automatic Recovery**: Auto-reconnection and fallback systems
- **User Feedback**: Clear error messages and recovery suggestions
- **Error Statistics**: Track error rates and resolution success
- **Critical Error Handling**: Immediate user notification for critical issues

### Performance Optimization
- **Auto-optimization**: Automatically adjusts performance based on system load
- **Performance Levels**: Performance, Balanced, and Quality modes
- **Real-time Monitoring**: Continuous performance metric tracking
- **Recommendations**: Performance improvement suggestions

## ♿ Accessibility

### Supported Features
- **VoiceOver**: Full screen reader support
- **Haptic Feedback**: Tactile feedback for interactions
- **Audio Cues**: Audio feedback for important events
- **High Contrast**: Enhanced visual contrast mode
- **Large Text**: Increased text size support
- **Reduce Motion**: Reduced animation for motion sensitivity
- **Color Blind Support**: Color-blind friendly interface

### Accessibility Settings
Access all accessibility features through the Settings panel:
- Toggle haptic feedback and audio cues
- Enable high contrast and large text modes
- Configure color blind support
- Monitor system accessibility status

## 🧪 Testing

### Testing Strategy
1. **Unit Tests**: Test individual components and managers
2. **Integration Tests**: Test end-to-end functionality
3. **Simulator Testing**: Test UI and gestures without robot
4. **Device Testing**: Full functionality with actual robot
5. **Performance Testing**: Multiple streams and visualizations

### Test Scenarios
- **Connection Testing**: WebSocket and video stream connectivity
- **Control Testing**: Hand gesture and gamepad input accuracy
- **Visualization Testing**: LIDAR, SLAM, and point cloud rendering
- **Error Recovery Testing**: Network disconnection and recovery
- **Performance Testing**: High load scenarios and optimization

## 📊 Performance

### System Requirements
- **Minimum**: Apple Vision Pro with 8GB RAM
- **Recommended**: Apple Vision Pro with 16GB RAM
- **Network**: Stable WiFi connection to robot network

### Performance Targets
- **Frame Rate**: 60 FPS (30 FPS minimum)
- **Memory Usage**: < 500MB under normal operation
- **CPU Usage**: < 80% under normal operation
- **Network Latency**: < 100ms to robot

### Optimization Features
- **Adaptive Quality**: Automatically adjusts quality based on performance
- **Efficient Rendering**: Optimized rendering for multiple streams
- **Memory Management**: Automatic memory cleanup and optimization
- **Background Processing**: Non-blocking data processing

## 🔒 Safety

### Safety Features
- **Emergency Stop**: Immediate robot halt functionality
- **Obstacle Warnings**: Real-time obstacle detection alerts
- **Safety Override**: Manual safety system override
- **Connection Monitoring**: Continuous connection health monitoring
- **Error Recovery**: Automatic recovery from common errors

### Safety Best Practices
- Always test in a safe environment
- Keep emergency stop accessible
- Monitor connection status
- Use appropriate speed settings
- Follow robot-specific safety guidelines

## 🤝 Contributing

### Development Guidelines
- Follow Swift coding conventions
- Add comprehensive documentation
- Include unit tests for new features
- Test on both simulator and device
- Ensure accessibility compliance

### Code Style
- Use SwiftUI for UI components
- Implement Combine for reactive programming
- Follow MVVM architecture pattern
- Use dependency injection for managers
- Include error handling for all operations

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- **ROS2 Community**: For the excellent robotics framework
- **Apple**: For VisionOS and spatial computing capabilities
- **SwiftUI Team**: For the modern UI framework
- **RealityKit Team**: For 3D rendering capabilities

## 📞 Support

For support and questions:
- Check the debug console for error details
- Review the tutorial for usage guidance
- Consult the settings for configuration options
- Monitor performance metrics for optimization

---

**ROSNavigator** - Bringing immersive teleoperation to VisionOS 🚀

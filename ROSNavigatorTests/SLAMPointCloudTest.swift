import XCTest
import Combine
@testable import F3ROSTeleops

@MainActor
final class SLAMPointCloudTest: XCTestCase {
    var ros2Manager: ROS2WebSocketManager!
    var cancellables: Set<AnyCancellable> = []
    let mapExpectation = XCTestExpectation(description: "SLAM Map Message Received")
    let pointCloudExpectation = XCTestExpectation(description: "Point Cloud Message Received")
    
    override func setUpWithError() throws {
        super.setUp()
        ros2Manager = ROS2WebSocketManager.shared
        ros2Manager.updateServerIP("192.168.1.49")
        ros2Manager.connect()
        
        // Observe connection state
        ros2Manager.$connectionState
            .sink { state in
                print("[\(Date().formatted(date: .omitted, time: .shortened))] 🔌 Connection state: \(state)")
                if case .connected = state {
                    print("[\(Date().formatted(date: .omitted, time: .shortened))] ✅ WebSocket connected. Subscribing to SLAM and Point Cloud topics...")
                    self.subscribeToSLAMAndPointCloud()
                } else if case .error(let error) = state {
                    XCTFail("WebSocket connection error: \(error)")
                    self.mapExpectation.fulfill()
                    self.pointCloudExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
    }

    override func tearDownWithError() throws {
        ros2Manager.disconnect()
        cancellables.forEach { $0.cancel() }
        super.tearDown()
    }

    func testSLAMAndPointCloudTopics() {
        // Wait for messages to be received (with longer timeout since these might be less frequent)
        wait(for: [mapExpectation, pointCloudExpectation], timeout: 30.0)
    }

    private func subscribeToSLAMAndPointCloud() {
        // Subscribe to SLAM map topic
        ros2Manager.subscribe(to: "/map", messageType: "nav_msgs/msg/OccupancyGrid") { message in
            print("[\(Date().formatted(date: .omitted, time: .shortened))] ✅ Received SLAM map message")
            print("[\(Date().formatted(date: .omitted, time: .shortened))] 📋 Operation: \((message as? [String: Any])?["op"] ?? "N/A")")
            print("[\(Date().formatted(date: .omitted, time: .shortened))] 📨 Received: \(message)")
            self.mapExpectation.fulfill()
        }
        
        // Subscribe to point cloud topic
        ros2Manager.subscribe(to: "/cloud_map", messageType: "sensor_msgs/msg/PointCloud2") { message in
            print("[\(Date().formatted(date: .omitted, time: .shortened))] ✅ Received point cloud message")
            print("[\(Date().formatted(date: .omitted, time: .shortened))] 📋 Operation: \((message as? [String: Any])?["op"] ?? "N/A")")
            print("[\(Date().formatted(date: .omitted, time: .shortened))] 📨 Received: \(message)")
            self.pointCloudExpectation.fulfill()
        }
    }
}

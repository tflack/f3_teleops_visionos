//
//  Twist.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation

/// ROS2 geometry_msgs/Twist message for velocity commands
struct Twist: Codable {
    let linear: Vector3
    let angular: Vector3
    
    struct Vector3: Codable {
        let x: Double
        let y: Double
        let z: Double
        
        init(x: Double = 0.0, y: Double = 0.0, z: Double = 0.0) {
            self.x = x
            self.y = y
            self.z = z
        }
    }
    
    init(linear: Vector3 = Vector3(), angular: Vector3 = Vector3()) {
        self.linear = linear
        self.angular = angular
    }
    
    /// Create a Twist message for robot movement
    static func movement(forward: Double, strafe: Double, rotation: Double) -> Twist {
        return Twist(
            linear: Vector3(x: forward, y: strafe, z: 0.0),
            angular: Vector3(x: 0.0, y: 0.0, z: rotation)
        )
    }
    
    /// Create a stop command
    static func stop() -> Twist {
        return Twist()
    }
}

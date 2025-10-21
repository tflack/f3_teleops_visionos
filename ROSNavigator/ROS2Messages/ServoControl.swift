//
//  ServoControl.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine

/// ROS2 servo control message for arm control
struct ServoControl: Codable {
    let duration: Double
    let positionUnit: String
    let position: [ServoPosition]
    
    struct ServoPosition: Codable {
        let id: Int
        let position: Int
        
        enum CodingKeys: String, CodingKey {
            case id
            case position
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case duration
        case positionUnit = "position_unit"
        case position
    }
    
    /// Create a servo control message for arm control
    static func armControl(
        joint1: Int = 500,
        joint2: Int = 750,
        joint3: Int = 0,
        joint4: Int = 375,
        joint5: Int = 500,
        gripper: Int = 500,
        duration: Double = 0.1
    ) -> ServoControl {
        return ServoControl(
            duration: duration,
            positionUnit: "pulse",
            position: [
                ServoPosition(id: 1, position: joint1),
                ServoPosition(id: 2, position: joint2),
                ServoPosition(id: 3, position: joint3),
                ServoPosition(id: 4, position: joint4),
                ServoPosition(id: 5, position: joint5),
                ServoPosition(id: 10, position: gripper)
            ]
        )
    }
    
    /// Create a servo control message for individual joint control
    static func jointControl(jointId: Int, position: Int, duration: Double = 0.1) -> ServoControl {
        return ServoControl(
            duration: duration,
            positionUnit: "pulse",
            position: [ServoPosition(id: jointId, position: position)]
        )
    }
}

/// Arm position state for UI
class ArmPosition: ObservableObject {
    @Published var joint1: Int = 500
    @Published var joint2: Int = 750
    @Published var joint3: Int = 0
    @Published var joint4: Int = 375
    @Published var joint5: Int = 500
    @Published var gripper: Int = 500
    
    /// Reset to default positions
    func reset() {
        joint1 = 500
        joint2 = 750
        joint3 = 0
        joint4 = 375
        joint5 = 500
        gripper = 500
    }
    
    /// Create ServoControl message from current positions
    func toServoControl(duration: Double = 0.1) -> ServoControl {
        return ServoControl.armControl(
            joint1: joint1,
            joint2: joint2,
            joint3: joint3,
            joint4: joint4,
            joint5: joint5,
            gripper: gripper,
            duration: duration
        )
    }
    
    /// Update position with smoothing
    func updatePosition(jointId: Int, targetPosition: Int, smoothingFactor: Double = 0.15) {
        let currentPosition: Int
        let clampedTarget = max(0, min(1000, targetPosition))
        
        switch jointId {
        case 1:
            currentPosition = joint1
            joint1 = Int(Double(currentPosition) + (Double(clampedTarget) - Double(currentPosition)) * smoothingFactor)
        case 2:
            currentPosition = joint2
            joint2 = Int(Double(currentPosition) + (Double(clampedTarget) - Double(currentPosition)) * smoothingFactor)
        case 3:
            currentPosition = joint3
            joint3 = Int(Double(currentPosition) + (Double(clampedTarget) - Double(currentPosition)) * smoothingFactor)
        case 4:
            currentPosition = joint4
            joint4 = Int(Double(currentPosition) + (Double(clampedTarget) - Double(currentPosition)) * smoothingFactor)
        case 5:
            currentPosition = joint5
            joint5 = Int(Double(currentPosition) + (Double(clampedTarget) - Double(currentPosition)) * smoothingFactor)
        case 10:
            currentPosition = gripper
            gripper = Int(Double(currentPosition) + (Double(clampedTarget) - Double(currentPosition)) * smoothingFactor)
        default:
            break
        }
    }
}

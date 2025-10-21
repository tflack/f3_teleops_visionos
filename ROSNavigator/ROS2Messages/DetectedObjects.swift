//
//  DetectedObjects.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation

/// ROS2 interfaces/DetectedObjects message for object detection results
struct DetectedObjects: Codable {
    let objects: [DetectedObject]
    
    struct DetectedObject: Codable {
        let className: String
        let confidence: Double
        let position: Position
        let boundingBox: BoundingBox
        let distance: Double
        
        struct Position: Codable {
            let x: Double
            let y: Double
            let z: Double
        }
        
        struct BoundingBox: Codable {
            let x: Int
            let y: Int
            let width: Int
            let height: Int
        }
        
        enum CodingKeys: String, CodingKey {
            case className = "class_name"
            case confidence
            case position
            case boundingBox = "bounding_box"
            case distance
        }
    }
}

/// Simplified detected object for UI display
struct DetectedObjectInfo: Identifiable {
    let id = UUID()
    let className: String
    let confidence: Double
    let position: (x: Double, y: Double, z: Double)
    let boundingBox: (x: Int, y: Int, width: Int, height: Int)
    let distance: Double
    let timestamp: Date
    
    init(from detectedObject: DetectedObjects.DetectedObject) {
        self.className = detectedObject.className
        self.confidence = detectedObject.confidence
        self.position = (x: detectedObject.position.x, y: detectedObject.position.y, z: detectedObject.position.z)
        self.boundingBox = (x: detectedObject.boundingBox.x, y: detectedObject.boundingBox.y, 
                           width: detectedObject.boundingBox.width, height: detectedObject.boundingBox.height)
        self.distance = detectedObject.distance
        self.timestamp = Date()
    }
    
    /// Get confidence as percentage
    var confidencePercentage: Int {
        return Int(confidence * 100)
    }
    
    /// Get formatted distance string
    var distanceString: String {
        return String(format: "%.2fm", distance)
    }
}

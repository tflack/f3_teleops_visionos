//
//  LaserScan.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation

/// ROS2 sensor_msgs/LaserScan message for LIDAR data
struct LaserScan: Codable {
    let header: Header
    let angleMin: Double
    let angleMax: Double
    let angleIncrement: Double
    let timeIncrement: Double
    let scanTime: Double
    let rangeMin: Double
    let rangeMax: Double
    let ranges: [Double]
    let intensities: [Double]
    
    struct Header: Codable {
        let stamp: TimeStamp
        let frameId: String
        
        struct TimeStamp: Codable {
            let sec: Int32
            let nanosec: UInt32
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case header
        case angleMin = "angle_min"
        case angleMax = "angle_max"
        case angleIncrement = "angle_increment"
        case timeIncrement = "time_increment"
        case scanTime = "scan_time"
        case rangeMin = "range_min"
        case rangeMax = "range_max"
        case ranges
        case intensities
    }
    
    /// Get the number of points in the scan
    var pointCount: Int {
        return ranges.count
    }
    
    /// Get a point at the given index with angle and distance
    func point(at index: Int) -> (angle: Double, distance: Double)? {
        guard index >= 0 && index < ranges.count else { return nil }
        
        let angle = angleMin + Double(index) * angleIncrement
        let distance = ranges[index]
        
        // Filter out invalid readings
        guard distance >= rangeMin && distance <= rangeMax && 
              distance.isFinite && !distance.isNaN else {
            return nil
        }
        
        return (angle: angle, distance: distance)
    }
    
    /// Get all valid points as (angle, distance) tuples
    func validPoints() -> [(angle: Double, distance: Double)] {
        var points: [(angle: Double, distance: Double)] = []
        
        for i in 0..<ranges.count {
            if let point = point(at: i) {
                points.append(point)
            }
        }
        
        return points
    }
}

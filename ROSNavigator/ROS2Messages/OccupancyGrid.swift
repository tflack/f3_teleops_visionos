//
//  OccupancyGrid.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation

/// ROS2 nav_msgs/OccupancyGrid message for SLAM map data
struct OccupancyGrid: Codable {
    let header: Header
    let info: MapMetaData
    let data: [Int8]
    
    struct Header: Codable {
        let stamp: TimeStamp
        let frameId: String
        
        struct TimeStamp: Codable {
            let sec: Int32
            let nanosec: UInt32
        }
    }
    
    struct MapMetaData: Codable {
        let mapLoadTime: TimeStamp
        let resolution: Double
        let width: UInt32
        let height: UInt32
        let origin: Pose
        
        struct TimeStamp: Codable {
            let sec: Int32
            let nanosec: UInt32
        }
        
        struct Pose: Codable {
            let position: Point
            let orientation: Quaternion
            
            struct Point: Codable {
                let x: Double
                let y: Double
                let z: Double
            }
            
            struct Quaternion: Codable {
                let x: Double
                let y: Double
                let z: Double
                let w: Double
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case header
        case info
        case data
    }
    
    /// Get the occupancy value at the given grid coordinates
    func occupancyAt(x: Int, y: Int) -> Int8? {
        guard x >= 0 && x < Int(info.width) && y >= 0 && y < Int(info.height) else {
            return nil
        }
        
        let index = y * Int(info.width) + x
        guard index < data.count else { return nil }
        
        return data[index]
    }
    
    /// Get the occupancy value at world coordinates
    func occupancyAt(worldX: Double, worldY: Double) -> Int8? {
        let gridX = Int((worldX - info.origin.position.x) / info.resolution)
        let gridY = Int((worldY - info.origin.position.y) / info.resolution)
        
        return occupancyAt(x: gridX, y: gridY)
    }
    
    /// Convert grid coordinates to world coordinates
    func gridToWorld(x: Int, y: Int) -> (x: Double, y: Double) {
        let worldX = Double(x) * info.resolution + info.origin.position.x
        let worldY = Double(y) * info.resolution + info.origin.position.y
        return (x: worldX, y: worldY)
    }
    
    /// Convert world coordinates to grid coordinates
    func worldToGrid(x: Double, y: Double) -> (x: Int, y: Int) {
        let gridX = Int((x - info.origin.position.x) / info.resolution)
        let gridY = Int((y - info.origin.position.y) / info.resolution)
        return (x: gridX, y: gridY)
    }
    
    /// Get the total number of cells in the map
    var totalCells: Int {
        return Int(info.width * info.height)
    }
    
    /// Check if the map has valid data
    var isValid: Bool {
        return data.count == totalCells && info.width > 0 && info.height > 0
    }
}

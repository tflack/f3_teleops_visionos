//
//  PointCloud2.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation

/// ROS2 sensor_msgs/PointCloud2 message for 3D point cloud data
struct PointCloud2: Codable {
    let header: Header
    let height: UInt32
    let width: UInt32
    let fields: [PointField]
    let isBigendian: Bool
    let pointStep: UInt32
    let rowStep: UInt32
    let data: Data
    let isDense: Bool
    
    struct Header: Codable {
        let stamp: TimeStamp
        let frameId: String
        
        struct TimeStamp: Codable {
            let sec: Int32
            let nanosec: UInt32
        }
    }
    
    struct PointField: Codable {
        let name: String
        let offset: UInt32
        let datatype: UInt8
        let count: UInt32
        
        enum DataType: UInt8 {
            case int8 = 1
            case uint8 = 2
            case int16 = 3
            case uint16 = 4
            case int32 = 5
            case uint32 = 6
            case float32 = 7
            case float64 = 8
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case header
        case height
        case width
        case fields
        case isBigendian = "is_bigendian"
        case pointStep = "point_step"
        case rowStep = "row_step"
        case data
        case isDense = "is_dense"
    }
    
    /// Get the total number of points in the cloud
    var totalPoints: Int {
        return Int(width * height)
    }
    
    /// Find field offset by name
    func fieldOffset(for name: String) -> UInt32? {
        return fields.first { $0.name == name }?.offset
    }
    
    /// Parse a point at the given index
    func point(at index: Int) -> Point? {
        guard index >= 0 && index < totalPoints else { return nil }
        
        let offset = index * Int(pointStep)
        guard offset + Int(pointStep) <= data.count else { return nil }
        
        let pointData = data.subdata(in: offset..<offset + Int(pointStep))
        
        // Extract XYZ coordinates (assuming float32)
        guard let xOffset = fieldOffset(for: "x"),
              let yOffset = fieldOffset(for: "y"),
              let zOffset = fieldOffset(for: "z") else {
            return nil
        }
        
        let x = extractFloat32(from: pointData, at: Int(xOffset))
        let y = extractFloat32(from: pointData, at: Int(yOffset))
        let z = extractFloat32(from: pointData, at: Int(zOffset))
        
        // Extract RGB color if available
        var r: UInt8 = 128, g: UInt8 = 128, b: UInt8 = 128 // default gray
        
        if let rgbOffset = fieldOffset(for: "rgb") {
            let rgb = extractUInt32(from: pointData, at: Int(rgbOffset))
            r = UInt8((rgb >> 16) & 0xFF)
            g = UInt8((rgb >> 8) & 0xFF)
            b = UInt8(rgb & 0xFF)
        } else if let rgbaOffset = fieldOffset(for: "rgba") {
            let rgba = extractUInt32(from: pointData, at: Int(rgbaOffset))
            r = UInt8((rgba >> 16) & 0xFF)
            g = UInt8((rgba >> 8) & 0xFF)
            b = UInt8(rgba & 0xFF)
        }
        
        return Point(x: x, y: y, z: z, r: r, g: g, b: b)
    }
    
    /// Extract all valid points from the cloud
    func allPoints() -> [Point] {
        var points: [Point] = []
        
        for i in 0..<totalPoints {
            if let point = point(at: i) {
                points.append(point)
            }
        }
        
        return points
    }
    
    /// Sample points to avoid overwhelming the renderer
    func sampledPoints(maxCount: Int = 100000) -> [Point] {
        let allPoints = allPoints()
        
        if allPoints.count <= maxCount {
            return allPoints
        }
        
        let step = allPoints.count / maxCount
        return stride(from: 0, to: allPoints.count, by: step).compactMap { index in
            allPoints[index]
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractFloat32(from data: Data, at offset: Int) -> Float {
        guard offset + 4 <= data.count else { return 0.0 }
        
        let bytes = data.subdata(in: offset..<offset + 4)
        return bytes.withUnsafeBytes { bytes in
            bytes.load(as: Float.self)
        }
    }
    
    private func extractUInt32(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        
        let bytes = data.subdata(in: offset..<offset + 4)
        return bytes.withUnsafeBytes { bytes in
            bytes.load(as: UInt32.self)
        }
    }
}

/// Represents a single point in 3D space with color
struct Point {
    let x: Float
    let y: Float
    let z: Float
    let r: UInt8
    let g: UInt8
    let b: UInt8
    
    /// Check if the point has valid coordinates
    var isValid: Bool {
        return x.isFinite && y.isFinite && z.isFinite && !x.isNaN && !y.isNaN && !z.isNaN
    }
}

//
//  WindowCoordinator.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import SwiftUI
import RealityKit

@MainActor
class WindowCoordinator: ObservableObject {
    @Published var panels: [PanelID: PanelState] = [:]
    @Published var focusedPanel: PanelID?
    @Published var isResizing = false
    
    enum PanelID: String, CaseIterable {
        case status = "status"
        case alerts = "alerts"
        case camera = "camera"
        case lidar = "lidar"
        case slam = "slam"
        case pointCloud = "pointCloud"
        case controls = "controls"
        case actions = "actions"
    }
    
    struct PanelState {
        var position: SIMD3<Float>
        var rotation: SIMD3<Float>
        var scale: Float
        var isVisible: Bool
        var isFocused: Bool
        var zIndex: Int
        var size: CGSize
        var isResizable: Bool
        var isMovable: Bool
        
        init(
            position: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
            rotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
            scale: Float = 1.0,
            isVisible: Bool = true,
            isFocused: Bool = false,
            zIndex: Int = 0,
            size: CGSize = CGSize(width: 400, height: 300),
            isResizable: Bool = true,
            isMovable: Bool = true
        ) {
            self.position = position
            self.rotation = rotation
            self.scale = scale
            self.isVisible = isVisible
            self.isFocused = isFocused
            self.zIndex = zIndex
            self.size = size
            self.isResizable = isResizable
            self.isMovable = isMovable
        }
    }
    
    // Default panel positions in 3D space (in meters)
    private let defaultPositions: [PanelID: SIMD3<Float>] = [
        .status: SIMD3<Float>(0, 1.5, -1.0),        // Top center
        .alerts: SIMD3<Float>(-0.8, 1.2, -1.0),     // Top left
        .camera: SIMD3<Float>(0, 0, -1.5),          // Center, closer
        .lidar: SIMD3<Float>(-1.2, 0, -1.0),        // Left side
        .slam: SIMD3<Float>(-1.2, -0.5, -1.0),      // Left side, lower
        .pointCloud: SIMD3<Float>(1.2, 0, -1.0),    // Right side
        .controls: SIMD3<Float>(0, -1.0, -1.0),     // Bottom center
        .actions: SIMD3<Float>(1.2, -0.5, -1.0)     // Right side, lower
    ]
    
    // Default panel sizes
    private let defaultSizes: [PanelID: CGSize] = [
        .status: CGSize(width: 600, height: 200),
        .alerts: CGSize(width: 400, height: 300),
        .camera: CGSize(width: 800, height: 600),
        .lidar: CGSize(width: 400, height: 400),
        .slam: CGSize(width: 400, height: 400),
        .pointCloud: CGSize(width: 500, height: 500),
        .controls: CGSize(width: 600, height: 200),
        .actions: CGSize(width: 400, height: 500)
    ]
    
    init() {
        setupDefaultPanels()
    }
    
    // MARK: - Panel Management
    
    private func setupDefaultPanels() {
        for panelID in PanelID.allCases {
            let position = defaultPositions[panelID] ?? SIMD3<Float>(0, 0, -1.0)
            let size = defaultSizes[panelID] ?? CGSize(width: 400, height: 300)
            
            panels[panelID] = PanelState(
                position: position,
                size: size,
                isResizable: panelID != .controls, // Controls panel is fixed size
                isMovable: panelID != .camera      // Camera panel is fixed position
            )
        }
    }
    
    func getPanelState(_ panelID: PanelID) -> PanelState {
        return panels[panelID] ?? PanelState()
    }
    
    func updatePanelPosition(_ panelID: PanelID, position: SIMD3<Float>) {
        panels[panelID]?.position = position
    }
    
    func updatePanelRotation(_ panelID: PanelID, rotation: SIMD3<Float>) {
        panels[panelID]?.rotation = rotation
    }
    
    func updatePanelScale(_ panelID: PanelID, scale: Float) {
        panels[panelID]?.scale = scale
    }
    
    func updatePanelSize(_ panelID: PanelID, size: CGSize) {
        panels[panelID]?.size = size
    }
    
    func setPanelVisibility(_ panelID: PanelID, isVisible: Bool) {
        panels[panelID]?.isVisible = isVisible
    }
    
    func setPanelFocus(_ panelID: PanelID, isFocused: Bool) {
        if isFocused {
            // Unfocus all other panels
            for id in PanelID.allCases {
                panels[id]?.isFocused = false
            }
            focusedPanel = panelID
        } else {
            if focusedPanel == panelID {
                focusedPanel = nil
            }
        }
        panels[panelID]?.isFocused = isFocused
    }
    
    func bringPanelToFront(_ panelID: PanelID) {
        let maxZIndex = panels.values.map { $0.zIndex }.max() ?? 0
        panels[panelID]?.zIndex = maxZIndex + 1
        setPanelFocus(panelID, isFocused: true)
    }
    
    // MARK: - Layout Management
    
    func resetPanelLayout() {
        setupDefaultPanels()
        focusedPanel = nil
    }
    
    func arrangePanelsInArc(radius: Float = 1.5, startAngle: Float = -Float.pi/3, endAngle: Float = Float.pi/3) {
        let panelIDs = PanelID.allCases.filter { $0 != .camera && $0 != .controls }
        let angleStep = (endAngle - startAngle) / Float(panelIDs.count - 1)
        
        for (index, panelID) in panelIDs.enumerated() {
            let angle = startAngle + Float(index) * angleStep
            let x = radius * sin(angle)
            let z = -radius * cos(angle)
            let position = SIMD3<Float>(x, 0, z)
            
            updatePanelPosition(panelID, position: position)
            
            // Rotate panel to face user
            let rotation = SIMD3<Float>(0, angle, 0)
            updatePanelRotation(panelID, rotation: rotation)
        }
    }
    
    func arrangePanelsInGrid(columns: Int = 3, spacing: Float = 0.8) {
        let panelIDs = PanelID.allCases.filter { $0 != .camera && $0 != .controls }
        let rows = (panelIDs.count + columns - 1) / columns
        
        for (index, panelID) in panelIDs.enumerated() {
            let row = index / columns
            let col = index % columns
            
            let x = Float(col - columns/2) * spacing
            let y = Float(rows/2 - row) * spacing * 0.6
            let z: Float = -1.0
            
            let position = SIMD3<Float>(x, y, z)
            updatePanelPosition(panelID, position: position)
            updatePanelRotation(panelID, rotation: SIMD3<Float>(0, 0, 0))
        }
    }
    
    // MARK: - Gesture Handling
    
    func handleDragGesture(_ panelID: PanelID, translation: SIMD3<Float>) {
        guard panels[panelID]?.isMovable == true else { return }
        
        let currentPosition = panels[panelID]?.position ?? SIMD3<Float>(0, 0, 0)
        let newPosition = currentPosition + translation
        updatePanelPosition(panelID, position: newPosition)
    }
    
    func handlePinchGesture(_ panelID: PanelID, scale: Float) {
        guard panels[panelID]?.isResizable == true else { return }
        
        let currentScale = panels[panelID]?.scale ?? 1.0
        let newScale = max(0.5, min(2.0, currentScale * scale))
        updatePanelScale(panelID, scale: newScale)
    }
    
    func handleRotationGesture(_ panelID: PanelID, rotation: SIMD3<Float>) {
        let currentRotation = panels[panelID]?.rotation ?? SIMD3<Float>(0, 0, 0)
        let newRotation = currentRotation + rotation
        updatePanelRotation(panelID, rotation: newRotation)
    }
    
    // MARK: - Panel Interactions
    
    func togglePanel(_ panelID: PanelID) {
        let isVisible = panels[panelID]?.isVisible ?? false
        setPanelVisibility(panelID, isVisible: !isVisible)
    }
    
    func minimizePanel(_ panelID: PanelID) {
        updatePanelScale(panelID, scale: 0.1)
        setPanelFocus(panelID, isFocused: false)
    }
    
    func maximizePanel(_ panelID: PanelID) {
        updatePanelScale(panelID, scale: 1.5)
        bringPanelToFront(panelID)
    }
    
    func restorePanel(_ panelID: PanelID) {
        updatePanelScale(panelID, scale: 1.0)
        setPanelVisibility(panelID, isVisible: true)
    }
    
    // MARK: - Focus Management
    
    func focusNextPanel() {
        guard let currentFocus = focusedPanel else {
            setPanelFocus(.status, isFocused: true)
            return
        }
        
        let allPanels = PanelID.allCases
        guard let currentIndex = allPanels.firstIndex(of: currentFocus) else { return }
        
        let nextIndex = (currentIndex + 1) % allPanels.count
        setPanelFocus(allPanels[nextIndex], isFocused: true)
    }
    
    func focusPreviousPanel() {
        guard let currentFocus = focusedPanel else {
            setPanelFocus(.actions, isFocused: true)
            return
        }
        
        let allPanels = PanelID.allCases
        guard let currentIndex = allPanels.firstIndex(of: currentFocus) else { return }
        
        let previousIndex = currentIndex == 0 ? allPanels.count - 1 : currentIndex - 1
        setPanelFocus(allPanels[previousIndex], isFocused: true)
    }
    
    // MARK: - Panel Groups
    
    func showVisualizationPanels() {
        setPanelVisibility(.lidar, isVisible: true)
        setPanelVisibility(.slam, isVisible: true)
        setPanelVisibility(.pointCloud, isVisible: true)
    }
    
    func hideVisualizationPanels() {
        setPanelVisibility(.lidar, isVisible: false)
        setPanelVisibility(.slam, isVisible: false)
        setPanelVisibility(.pointCloud, isVisible: false)
    }
    
    func showControlPanels() {
        setPanelVisibility(.controls, isVisible: true)
        setPanelVisibility(.actions, isVisible: true)
    }
    
    func hideControlPanels() {
        setPanelVisibility(.controls, isVisible: false)
        setPanelVisibility(.actions, isVisible: false)
    }
    
    // MARK: - Performance Optimization
    
    func optimizeForPerformance() {
        // Reduce scale of non-essential panels
        for panelID in [.alerts, .actions] {
            updatePanelScale(panelID, scale: 0.8)
        }
        
        // Hide visualization panels if not needed
        hideVisualizationPanels()
    }
    
    func optimizeForVisibility() {
        // Increase scale of important panels
        for panelID in [.camera, .controls, .status] {
            updatePanelScale(panelID, scale: 1.2)
        }
        
        // Show all panels
        for panelID in PanelID.allCases {
            setPanelVisibility(panelID, isVisible: true)
        }
    }
}

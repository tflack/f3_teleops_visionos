//
//  InputCoordinator.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine

@MainActor
class InputCoordinator: ObservableObject {
    @Published var finalMovement = (forward: 0.0, strafe: 0.0)
    @Published var finalRotation = 0.0
    @Published var finalArmInput = (x: 0.0, y: 0.0)
    @Published var activeInputSource: InputSource = .none
    
    enum InputSource {
        case none
        case handGesture
        case gamepad
    }
    
    private let gamepadManager: GamepadManager
    private var cancellables = Set<AnyCancellable>()
    
    // Hand gesture inputs (from virtual joysticks)
    @Published var handMovement = (forward: 0.0, strafe: 0.0)
    @Published var handRotation = 0.0
    @Published var handArmInput = (x: 0.0, y: 0.0)
    
    // Gamepad priority settings
    private let gamepadPriority = true // Gamepad overrides hand gestures when connected
    
    init(gamepadManager: GamepadManager) {
        self.gamepadManager = gamepadManager
        setupInputMerging()
    }
    
    private func setupInputMerging() {
        // Combine gamepad and hand gesture inputs
        Publishers.CombineLatest4(
            gamepadManager.$isConnected,
            gamepadManager.$leftStick,
            gamepadManager.$rightStick,
            Publishers.CombineLatest3(
                $handMovement,
                $handRotation,
                $handArmInput
            )
        )
        .sink { [weak self] gamepadConnected, gamepadLeftStick, gamepadRightStick, handInputs in
            self?.mergeInputs(
                gamepadConnected: gamepadConnected,
                gamepadLeftStick: gamepadLeftStick,
                gamepadRightStick: gamepadRightStick,
                handMovement: handInputs.0,
                handRotation: handInputs.1,
                handArmInput: handInputs.2
            )
        }
        .store(in: &cancellables)
    }
    
    private func mergeInputs(
        gamepadConnected: Bool,
        gamepadLeftStick: (x: Double, y: Double),
        gamepadRightStick: (x: Double, y: Double),
        handMovement: (forward: Double, strafe: Double),
        handRotation: Double,
        handArmInput: (x: Double, y: Double)
    ) {
        if gamepadConnected && gamepadPriority {
            // Use gamepad input
            let gamepadMovement = gamepadManager.getMovementInput()
            let gamepadRotation = gamepadManager.getRotationInput()
            let gamepadArmInput = gamepadManager.getArmInput()
            
            finalMovement = gamepadMovement
            finalRotation = gamepadRotation
            finalArmInput = gamepadArmInput
            activeInputSource = .gamepad
        } else {
            // Use hand gesture input
            finalMovement = handMovement
            finalRotation = handRotation
            finalArmInput = handArmInput
            activeInputSource = .handGesture
        }
    }
    
    // MARK: - Hand Gesture Input Updates
    
    func updateHandMovement(forward: Double, strafe: Double) {
        handMovement = (forward: forward, strafe: strafe)
    }
    
    func updateHandRotation(_ rotation: Double) {
        handRotation = rotation
    }
    
    func updateHandArmInput(x: Double, y: Double) {
        handArmInput = (x: x, y: y)
    }
    
    // MARK: - Button Actions
    
    func handleButtonPress(_ button: GamepadManager.Button) -> ButtonAction {
        switch button {
        case .a:
            return .emergencyStop
        case .b:
            return .resetPosition
        case .x:
            return .gripperClose
        case .y:
            return .gripperOpen
        case .leftBumper:
            return .decreaseSpeed
        case .rightBumper:
            return .increaseSpeed
        case .select:
            return .toggleArmMode
        case .start:
            return .toggleSafetyOverride
        case .dpadUp:
            return .gripperOpen
        case .dpadDown:
            return .gripperClose
        case .dpadLeft:
            return .wristRotateLeft
        case .dpadRight:
            return .wristRotateRight
        default:
            return .none
        }
    }
    
    // MARK: - Input State Queries
    
    var hasActiveInput: Bool {
        let hasMovement = abs(finalMovement.forward) > 0.01 || abs(finalMovement.strafe) > 0.01
        let hasRotation = abs(finalRotation) > 0.01
        let hasArmInput = abs(finalArmInput.x) > 0.01 || abs(finalArmInput.y) > 0.01
        
        return hasMovement || hasRotation || hasArmInput
    }
    
    var inputSourceDescription: String {
        switch activeInputSource {
        case .none:
            return "No Input"
        case .handGesture:
            return "Hand Gestures"
        case .gamepad:
            return "Gamepad (\(gamepadManager.gamepadName))"
        }
    }
}

// MARK: - Button Actions

enum ButtonAction {
    case none
    case emergencyStop
    case resetPosition
    case gripperClose
    case gripperOpen
    case decreaseSpeed
    case increaseSpeed
    case toggleArmMode
    case toggleSafetyOverride
    case wristRotateLeft
    case wristRotateRight
    case executeAction(String)
}

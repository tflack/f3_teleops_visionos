//
//  GamepadManager.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import GameController
import Combine

@MainActor
class GamepadManager: ObservableObject {
    @Published var isConnected = false
    @Published var gamepadName: String = ""
    @Published var leftStick = (x: 0.0, y: 0.0)
    @Published var rightStick = (x: 0.0, y: 0.0)
    @Published var leftTrigger: Float = 0.0
    @Published var rightTrigger: Float = 0.0
    @Published var buttonStates: [Int: Bool] = [:]
    
    private var gamepad: GCController?
    private var cancellables = Set<AnyCancellable>()
    private let deadzone: Float = 0.1
    
    // Button mappings (Xbox/PlayStation style)
    enum Button: Int, CaseIterable {
        case a = 0      // Cross (PS) / A (Xbox)
        case b = 1      // Circle (PS) / B (Xbox)
        case x = 2      // Square (PS) / X (Xbox)
        case y = 3      // Triangle (PS) / Y (Xbox)
        case leftBumper = 4
        case rightBumper = 5
        case leftTrigger = 6
        case rightTrigger = 7
        case select = 8
        case start = 9
        case leftStick = 10
        case rightStick = 11
        case dpadUp = 12
        case dpadDown = 13
        case dpadLeft = 14
        case dpadRight = 15
    }
    
    init() {
        setupGamepadNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupGamepadNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gamepadDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(gamepadDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )
    }
    
    @objc private func gamepadDidConnect(_ notification: Notification) {
        guard let controller = notification.object as? GCController else { return }
        
        gamepad = controller
        isConnected = true
        gamepadName = controller.productCategory
        
        print("🎮 Gamepad connected: \(gamepadName)")
        
        setupGamepadInputHandling()
    }
    
    @objc private func gamepadDidDisconnect(_ notification: Notification) {
        gamepad = nil
        isConnected = false
        gamepadName = ""
        
        // Reset all inputs
        leftStick = (0, 0)
        rightStick = (0, 0)
        leftTrigger = 0
        rightTrigger = 0
        buttonStates.removeAll()
        
        print("🎮 Gamepad disconnected")
    }
    
    private func setupGamepadInputHandling() {
        guard let gamepad = gamepad?.extendedGamepad else { return }
        
        // Left stick (movement)
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            Task { @MainActor in
                self?.leftStick = (
                    x: self?.applyDeadzone(Double(xValue)) ?? 0,
                    y: self?.applyDeadzone(Double(yValue)) ?? 0
                )
            }
        }
        
        // Right stick (rotation/arm)
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            Task { @MainActor in
                self?.rightStick = (
                    x: self?.applyDeadzone(Double(xValue)) ?? 0,
                    y: self?.applyDeadzone(Double(yValue)) ?? 0
                )
            }
        }
        
        // Triggers
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
            Task { @MainActor in
                self?.leftTrigger = value
            }
        }
        
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            Task { @MainActor in
                self?.rightTrigger = value
            }
        }
        
        // Buttons
        setupButtonHandlers(gamepad: gamepad)
    }
    
    private func setupButtonHandlers(gamepad: GCExtendedGamepad) {
        // A button (Emergency stop)
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.a.rawValue] = pressed
            }
        }
        
        // B button (Reset/Execute horizontal action)
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.b.rawValue] = pressed
            }
        }
        
        // X button (Gripper close/Execute place_center)
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.x.rawValue] = pressed
            }
        }
        
        // Y button (Gripper open/Execute garbage_pick)
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.y.rawValue] = pressed
            }
        }
        
        // Left bumper (Decrease speed)
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.leftBumper.rawValue] = pressed
            }
        }
        
        // Right bumper (Increase speed)
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.rightBumper.rawValue] = pressed
            }
        }
        
        // Select button (Toggle arm mode)
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.select.rawValue] = pressed
            }
        }
        
        // Start button (Toggle safety override)
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.start.rawValue] = pressed
            }
        }
        
        // D-pad
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.dpadUp.rawValue] = pressed
            }
        }
        
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.dpadDown.rawValue] = pressed
            }
        }
        
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.dpadLeft.rawValue] = pressed
            }
        }
        
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, value, pressed in
            Task { @MainActor in
                self?.buttonStates[Button.dpadRight.rawValue] = pressed
            }
        }
    }
    
    private func applyDeadzone(_ value: Double) -> Double {
        let absValue = abs(value)
        if absValue < Double(deadzone) {
            return 0.0
        }
        
        // Rescale to remove deadzone
        let scaledValue = (absValue - Double(deadzone)) / (1.0 - Double(deadzone))
        return value < 0 ? -scaledValue : scaledValue
    }
    
    // MARK: - Button State Queries
    
    func isButtonPressed(_ button: Button) -> Bool {
        return buttonStates[button.rawValue] ?? false
    }
    
    func isButtonJustPressed(_ button: Button) -> Bool {
        // This would need to track previous state for edge detection
        // For now, just return current state
        return isButtonPressed(button)
    }
    
    // MARK: - Input Processing
    
    func getMovementInput() -> (forward: Double, strafe: Double) {
        return (forward: leftStick.y, strafe: -leftStick.x) // Invert X for intuitive control
    }
    
    func getRotationInput() -> Double {
        return -rightStick.x // Invert for intuitive control
    }
    
    func getArmInput() -> (x: Double, y: Double) {
        return (x: rightStick.x, y: rightStick.y)
    }
    
    func getTriggerInput() -> (left: Double, right: Double) {
        return (left: Double(leftTrigger), right: Double(rightTrigger))
    }
}

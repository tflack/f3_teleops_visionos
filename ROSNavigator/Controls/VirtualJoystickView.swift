//
//  VirtualJoystickView.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import SwiftUI

struct VirtualJoystickView: View {
    @Binding var state: JoystickState
    let label: String
    let color: Color
    let deadzone: Double
    let maxDistance: Double
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    init(
        state: Binding<JoystickState>,
        label: String,
        color: Color = .blue,
        deadzone: Double = 0.1,
        maxDistance: Double = 50.0
    ) {
        self._state = state
        self.label = label
        self.color = color
        self.deadzone = deadzone
        self.maxDistance = maxDistance
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                // Background circle
                Circle()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.3), lineWidth: 2)
                    )
                
                // Deadzone indicator
                Circle()
                    .fill(Color.clear)
                    .frame(width: deadzone * 120, height: deadzone * 120)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.2), lineWidth: 1)
                    )
                
                // Joystick knob
                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(dragOffset)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isDragging)
                
                // Center crosshair
                if !isDragging {
                    VStack {
                        Rectangle()
                            .fill(color.opacity(0.3))
                            .frame(width: 2, height: 20)
                        Rectangle()
                            .fill(color.opacity(0.3))
                            .frame(width: 20, height: 2)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        updateJoystickPosition(value.translation)
                    }
                    .onEnded { _ in
                        isDragging = false
                        resetJoystick()
                    }
            )
            
            // Value display
            HStack {
                Text("X: \(String(format: "%.2f", state.values.x))")
                    .font(.caption2)
                    .fontDesign(.monospaced)
                Text("Y: \(String(format: "%.2f", state.values.y))")
                    .font(.caption2)
                    .fontDesign(.monospaced)
            }
            .foregroundColor(.secondary)
        }
    }
    
    private func updateJoystickPosition(_ translation: CGSize) {
        let distance = sqrt(pow(translation.width, 2) + pow(translation.height, 2))
        let maxDist = maxDistance
        
        if distance <= maxDist {
            dragOffset = translation
        } else {
            let angle = atan2(translation.height, translation.width)
            dragOffset = CGSize(
                width: cos(angle) * maxDist,
                height: sin(angle) * maxDist
            )
        }
        
        // Convert to normalized values (-1 to 1)
        let normalizedX = dragOffset.width / maxDist
        let normalizedY = -dragOffset.height / maxDist // Invert Y for intuitive control
        
        // Apply deadzone
        let magnitude = sqrt(pow(normalizedX, 2) + pow(normalizedY, 2))
        if magnitude < deadzone {
            state.values = (x: 0, y: 0)
        } else {
            // Scale values to remove deadzone
            let scaledMagnitude = (magnitude - deadzone) / (1.0 - deadzone)
            let scaledX = (normalizedX / magnitude) * scaledMagnitude
            let scaledY = (normalizedY / magnitude) * scaledMagnitude
            
            state.values = (x: scaledX, y: scaledY)
        }
    }
    
    private func resetJoystick() {
        withAnimation(.easeOut(duration: 0.2)) {
            dragOffset = .zero
            state.values = (x: 0, y: 0)
        }
    }
}

// MARK: - Joystick State

struct JoystickState {
    var values: (x: Double, y: Double) = (0, 0)
    var isActive: Bool = false
    var lastUpdate: Date = Date()
    
    var magnitude: Double {
        return sqrt(pow(values.x, 2) + pow(values.y, 2))
    }
    
    var angle: Double {
        return atan2(values.y, values.x)
    }
    
    mutating func updateValues(_ newValues: (x: Double, y: Double)) {
        values = newValues
        isActive = magnitude > 0.01
        lastUpdate = Date()
    }
    
    mutating func reset() {
        values = (0, 0)
        isActive = false
        lastUpdate = Date()
    }
}

// MARK: - Dual Joystick View

struct DualJoystickView: View {
    @Binding var leftJoystick: JoystickState
    @Binding var rightJoystick: JoystickState
    let leftLabel: String
    let rightLabel: String
    let leftColor: Color
    let rightColor: Color
    
    init(
        leftJoystick: Binding<JoystickState>,
        rightJoystick: Binding<JoystickState>,
        leftLabel: String = "Movement",
        rightLabel: String = "Rotation",
        leftColor: Color = .blue,
        rightColor: Color = .green
    ) {
        self._leftJoystick = leftJoystick
        self._rightJoystick = rightJoystick
        self.leftLabel = leftLabel
        self.rightLabel = rightLabel
        self.leftColor = leftColor
        self.rightColor = rightColor
    }
    
    var body: some View {
        HStack(spacing: 40) {
            VirtualJoystickView(
                state: $leftJoystick,
                label: leftLabel,
                color: leftColor
            )
            
            VirtualJoystickView(
                state: $rightJoystick,
                label: rightLabel,
                color: rightColor
            )
        }
    }
}

// MARK: - Joystick Control Panel

struct JoystickControlPanel: View {
    @Binding var leftJoystick: JoystickState
    @Binding var rightJoystick: JoystickState
    let onValuesChanged: ((JoystickState, JoystickState) -> Void)?
    
    @State private var controlMode: ControlMode = .manual
    @State private var speed: Double = 0.5
    @State private var isEmergencyStop = false
    
    enum ControlMode {
        case manual
        case arm
        case autonomous
    }
    
    init(
        leftJoystick: Binding<JoystickState>,
        rightJoystick: Binding<JoystickState>,
        onValuesChanged: ((JoystickState, JoystickState) -> Void)? = nil
    ) {
        self._leftJoystick = leftJoystick
        self._rightJoystick = rightJoystick
        self.onValuesChanged = onValuesChanged
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Control Mode Selector
            Picker("Control Mode", selection: $controlMode) {
                Text("Manual").tag(ControlMode.manual)
                Text("Arm").tag(ControlMode.arm)
                Text("Autonomous").tag(ControlMode.autonomous)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: controlMode) { _, newMode in
                updateRightJoystickLabel(for: newMode)
            }
            
            // Speed Control
            VStack {
                Text("Speed: \(Int(speed * 100))%")
                    .font(.headline)
                
                Slider(value: $speed, in: 0...1)
                    .accentColor(.blue)
            }
            
            // Emergency Stop
            Button(action: {
                isEmergencyStop.toggle()
                if isEmergencyStop {
                    leftJoystick.reset()
                    rightJoystick.reset()
                }
            }) {
                Text(isEmergencyStop ? "EMERGENCY STOP" : "E-STOP")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .background(isEmergencyStop ? .red : .gray)
                    .cornerRadius(10)
            }
            
            // Joysticks
            DualJoystickView(
                leftJoystick: $leftJoystick,
                rightJoystick: $rightJoystick,
                leftLabel: "Movement",
                rightLabel: rightJoystickLabel,
                leftColor: .blue,
                rightColor: rightJoystickColor
            )
            .disabled(isEmergencyStop)
            
            // Status Display
            VStack(alignment: .leading, spacing: 4) {
                Text("Left: \(formatJoystickValues(leftJoystick))")
                    .font(.caption)
                    .fontDesign(.monospaced)
                Text("Right: \(formatJoystickValues(rightJoystick))")
                    .font(.caption)
                    .fontDesign(.monospaced)
                Text("Speed: \(Int(speed * 100))%")
                    .font(.caption)
                    .fontDesign(.monospaced)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.black.opacity(0.1))
        .cornerRadius(15)
        .onChange(of: leftJoystick.values) { _, _ in
            notifyValuesChanged()
        }
        .onChange(of: rightJoystick.values) { _, _ in
            notifyValuesChanged()
        }
    }
    
    private var rightJoystickLabel: String {
        switch controlMode {
        case .manual:
            return "Rotation"
        case .arm:
            return "Arm Control"
        case .autonomous:
            return "Override"
        }
    }
    
    private var rightJoystickColor: Color {
        switch controlMode {
        case .manual:
            return .green
        case .arm:
            return .orange
        case .autonomous:
            return .purple
        }
    }
    
    private func updateRightJoystickLabel(for mode: ControlMode) {
        // Reset right joystick when switching modes
        rightJoystick.reset()
    }
    
    private func formatJoystickValues(_ joystick: JoystickState) -> String {
        return "(\(String(format: "%.2f", joystick.values.x)), \(String(format: "%.2f", joystick.values.y)))"
    }
    
    private func notifyValuesChanged() {
        onValuesChanged?(leftJoystick, rightJoystick)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        JoystickControlPanel(
            leftJoystick: .constant(JoystickState()),
            rightJoystick: .constant(JoystickState())
        )
    }
    .padding()
}

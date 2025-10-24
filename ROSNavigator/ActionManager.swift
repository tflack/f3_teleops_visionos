//
//  ActionManager.swift
//  ROSNavigator
//
//  Created by Tim Flack on 10/21/25.
//

import Foundation
import Combine

@MainActor
class ActionManager: ObservableObject {
    @Published var availableActions: ActionData?
    @Published var isLoading = false
    @Published var lastError: String?
    
    private let ros2Manager: ROS2WebSocketManager
    private var cancellables = Set<AnyCancellable>()
    
    struct ActionData: Codable {
        let allActions: [String]
        let categories: ActionCategories
        let totalCount: Int
        
        struct ActionCategories: Codable {
            let initialization: [String]
            let pickPlace: [String]
            let garbageWaste: [String]
            let navigation: [String]
            let handVoice: [String]
            let positioning: [String]
            let other: [String]
            
            enum CodingKeys: String, CodingKey {
                case initialization
                case pickPlace = "pick_place"
                case garbageWaste = "garbage_waste"
                case navigation
                case handVoice = "hand_voice"
                case positioning
                case other
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case allActions = "all_actions"
            case categories
            case totalCount = "total_count"
        }
    }
    
    init(ros2Manager: ROS2WebSocketManager) {
        self.ros2Manager = ros2Manager
    }
    
    // MARK: - Action Loading
    
    func loadAvailableActions() {
        guard !isLoading else { return }
        
        isLoading = true
        lastError = nil
        
        ros2Manager.callService(service: "/list_available_actions", request: [:]) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    self?.parseActionResponse(response)
                case .failure(let error):
                    self?.lastError = error.localizedDescription
                    print("❌ Failed to load actions: \(error)")
                }
            }
        }
    }
    
    private func parseActionResponse(_ response: [String: Any]) {
        guard let success = response["success"] as? Bool,
              success,
              let message = response["message"] as? String,
              let data = message.data(using: .utf8) else {
            lastError = "Invalid action response format"
            return
        }
        
        do {
            let actionData = try JSONDecoder().decode(ActionData.self, from: data)
            availableActions = actionData
            print("✅ Loaded \(actionData.totalCount) actions")
        } catch {
            lastError = "Failed to parse actions: \(error.localizedDescription)"
            print("❌ Action parsing error: \(error)")
        }
    }
    
    // MARK: - Action Execution
    
    func executeAction(_ actionName: String) {
        guard !actionName.isEmpty else {
            lastError = "Action name cannot be empty"
            return
        }
        
        let actionMessage = ["data": actionName]
        ros2Manager.publish(to: "/execute_action", message: actionMessage)
        print("🚀 Executing action: \(actionName)")
    }
    
    
    // MARK: - Action Categories
    
    func getActionsForCategory(_ category: ActionCategory) -> [String] {
        guard let actions = availableActions else { return [] }
        
        switch category {
        case .initialization:
            return actions.categories.initialization
        case .pickPlace:
            return actions.categories.pickPlace
        case .garbageWaste:
            return actions.categories.garbageWaste
        case .navigation:
            return actions.categories.navigation
        case .handVoice:
            return actions.categories.handVoice
        case .positioning:
            return actions.categories.positioning
        case .other:
            return actions.categories.other
        }
    }
    
    func getCategoryDisplayName(_ category: ActionCategory) -> String {
        switch category {
        case .initialization:
            return "Initialization"
        case .pickPlace:
            return "Pick & Place"
        case .garbageWaste:
            return "Garbage & Waste"
        case .navigation:
            return "Navigation"
        case .handVoice:
            return "Hand & Voice"
        case .positioning:
            return "Positioning"
        case .other:
            return "Other"
        }
    }
    
    // MARK: - Quick Actions
    
    func executeHorizontalAction() {
        executeAction("horizontal")
    }
    
    func executePlaceCenterAction() {
        executeAction("place_center")
    }
    
    func executeGarbagePickAction() {
        executeAction("garbage_pick")
    }
    
    // MARK: - Action Validation
    
    func isValidAction(_ actionName: String) -> Bool {
        guard let actions = availableActions else { return false }
        return actions.allActions.contains(actionName)
    }
    
    func getActionSuggestions(for query: String) -> [String] {
        guard let actions = availableActions, !query.isEmpty else { return [] }
        
        let lowercaseQuery = query.lowercased()
        return actions.allActions.filter { action in
            action.lowercased().contains(lowercaseQuery)
        }.prefix(10).map { $0 }
    }
}

// MARK: - Action Categories

enum ActionCategory: String, CaseIterable {
    case initialization
    case pickPlace
    case navigation
    case handVoice
    case positioning
    case garbageWaste
    case other
    
    var displayName: String {
        switch self {
        case .initialization:
            return "Initialization"
        case .pickPlace:
            return "Pick & Place"
        case .navigation:
            return "Navigation"
        case .handVoice:
            return "Hand & Voice"
        case .positioning:
            return "Positioning"
        case .garbageWaste:
            return "Garbage & Waste"
        case .other:
            return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .initialization:
            return "play.circle"
        case .pickPlace:
            return "hand.raised"
        case .navigation:
            return "location"
        case .handVoice:
            return "mic"
        case .positioning:
            return "target"
        case .garbageWaste:
            return "trash"
        case .other:
            return "ellipsis.circle"
        }
    }
}

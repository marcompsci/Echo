import Foundation

struct ActionSuggestion: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let systemImage: String
    let actionType: ActionType
    let requiresConfirmation: Bool

    enum ActionType: String, Codable, Sendable, Hashable {
        case openSettings
        case createReminder
        case createNote
        case openMaps
        case copyText
        case shareGuide
    }

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        systemImage: String,
        actionType: ActionType,
        requiresConfirmation: Bool = true
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.actionType = actionType
        self.requiresConfirmation = requiresConfirmation
    }
}

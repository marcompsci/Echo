import Foundation

// MARK: - What the Home Screen widget shows (written by the app, read by the widget)

nonisolated enum EchoWidgetShared {
    static let kind = "EchoHomeWidget"
    private static let nameKey = "widget.userName"
    private static let lastActionKey = "widget.lastAction"
    private static let lastActionDateKey = "widget.lastActionDate"

    static var userName: String { EchoAppGroup.defaults?.string(forKey: nameKey) ?? "" }
    static var lastAction: String? { EchoAppGroup.defaults?.string(forKey: lastActionKey) }
    static var lastActionDate: Date? { EchoAppGroup.defaults?.object(forKey: lastActionDateKey) as? Date }

    static func save(userName: String) {
        EchoAppGroup.defaults?.set(userName, forKey: nameKey)
    }

    static func save(lastAction: String, at date: Date = .now) {
        EchoAppGroup.defaults?.set(lastAction, forKey: lastActionKey)
        EchoAppGroup.defaults?.set(date, forKey: lastActionDateKey)
    }
}

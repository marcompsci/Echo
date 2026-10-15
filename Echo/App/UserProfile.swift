import Foundation

// MARK: - What Echo calls you

enum UserProfile {
    static let nameKey = "userName"

    static var name: String {
        (UserDefaults.standard.string(forKey: nameKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "What can I help you with, Omari?" — or without a name if none is set.
    static var helpGreeting: String {
        name.isEmpty ? "What can I help you with?" : "What can I help you with, \(name)?"
    }
}

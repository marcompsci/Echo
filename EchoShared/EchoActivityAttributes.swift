import Foundation
#if canImport(ActivityKit)
import ActivityKit

// MARK: - Echo on the Lock Screen & Dynamic Island (Live Activity)
// Shared by the app (starts/updates it) and the widget extension (draws it).

nonisolated struct EchoActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        enum Status: String, Codable, Hashable {
            case ready, listening, thinking, speaking, guiding, done
        }
        var status: Status
        /// Short line under the orb: "Ask me anything", current step, etc.
        var message: String
        /// Live Guide step number (0 = none).
        var step: Int = 0
    }

    /// The person's name, for "Hi Omari".
    var userName: String
}
#endif

import Foundation
import ActivityKit

// MARK: - Echo outside the app: Lock Screen + Dynamic Island
//
// Replaces the Picture-in-Picture orb (App Store risk). With permission
// (Settings → "Echo on Lock Screen & Dynamic Island"), Echo keeps a Live
// Activity running: the orb sits in the Dynamic Island and on the Lock Screen,
// shows what Echo is doing (listening, thinking, a Live Guide step), and a tap
// opens Hey Echo.

@MainActor
enum EchoPresence {
    static let enabledKey = "echoPresenceEnabled"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var isSupported: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    private static var activity: Activity<EchoActivityAttributes>? {
        Activity<EchoActivityAttributes>.activities.first
    }

    /// Starts (or refreshes) the Live Activity if the person turned it on.
    static func start() {
        guard isEnabled, isSupported else { return }
        if activity != nil { update(.ready, UserProfile.name.isEmpty ? "Tap to talk to Echo" : "Hi \(UserProfile.name) — tap to talk"); return }
        let attributes = EchoActivityAttributes(userName: UserProfile.name)
        let state = EchoActivityAttributes.ContentState(
            status: .ready,
            message: UserProfile.name.isEmpty ? "Tap to talk to Echo" : "Hi \(UserProfile.name) — tap to talk"
        )
        _ = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    static func update(_ status: EchoActivityAttributes.ContentState.Status, _ message: String, step: Int = 0) {
        guard isEnabled, let activity else { return }
        let state = EchoActivityAttributes.ContentState(status: status, message: message, step: step)
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// Back to the resting state after a conversation.
    static func rest() {
        update(.ready, UserProfile.name.isEmpty ? "Tap to talk to Echo" : "Hi \(UserProfile.name) — tap to talk")
    }

    static func stop() {
        Task {
            for activity in Activity<EchoActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

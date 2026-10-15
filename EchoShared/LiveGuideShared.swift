import Foundation

// MARK: - Live Guide shared state
//
// Compiled into BOTH the Echo app and the EchoLiveGuide broadcast extension.
// The app writes the goal; the extension (which runs while you use other apps)
// writes each step it finds. They talk through the App Group.

nonisolated enum EchoAppGroup {
    static let id = "group.phoronomicstudios.com.Echo"
    static var defaults: UserDefaults? { UserDefaults(suiteName: id) }
}

nonisolated struct LiveGuideStep: Codable, Sendable, Hashable, Identifiable {
    var id = UUID()
    var instruction: String
    var detail: String
    var date = Date()
}

nonisolated enum LiveGuideStatus: String, Codable, Sendable {
    case ready       // goal set, waiting for the broadcast to start
    case watching    // broadcast running, looking at the screen
    case thinking    // asking the guide service about the current screen
    case done        // goal reached
    case error       // something went wrong (see message)
    case ended       // broadcast stopped
}

nonisolated struct LiveGuideSession: Codable, Sendable {
    var id = UUID()
    var goal: String
    var status: LiveGuideStatus = .ready
    var steps: [LiveGuideStep] = []
    var message: String? = nil
    var safetyNotice: String? = nil
    var speakAloud: Bool = true
    /// Supabase function URL + publishable key, copied from the app's EchoConfig
    /// so the extension doesn't need its own copy.
    var endpoint: String
    var apiKey: String
    var startedAt = Date()
    var updatedAt = Date()

    var currentStep: LiveGuideStep? { steps.last }
}

nonisolated enum LiveGuideStore {
    private static let key = "liveGuideSession"
    static let darwinNotificationName = "phoronomicstudios.com.Echo.liveGuideUpdated"
    /// Bundle id of the broadcast extension (used by the system broadcast picker).
    static let extensionBundleID = "phoronomicstudios.com.Echo.EchoLiveGuide"

    static func load() -> LiveGuideSession? {
        guard let data = EchoAppGroup.defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LiveGuideSession.self, from: data)
    }

    static func save(_ session: LiveGuideSession) {
        var copy = session
        copy.updatedAt = Date()
        guard let data = try? JSONEncoder().encode(copy) else { return }
        EchoAppGroup.defaults?.set(data, forKey: key)
        postUpdate()
    }

    @discardableResult
    static func update(_ change: (inout LiveGuideSession) -> Void) -> LiveGuideSession? {
        guard var session = load() else { return nil }
        change(&session)
        save(session)
        return session
    }

    static func clear() {
        EchoAppGroup.defaults?.removeObject(forKey: key)
        postUpdate()
    }

    /// Wakes up any observer in the other process (app ↔ extension).
    static func postUpdate() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinNotificationName as CFString),
            nil, nil, true
        )
    }
}

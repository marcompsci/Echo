import Foundation

// MARK: - Developer Inspector
//
// Developers asked for transparency: which model answered, how long it took,
// what was sent, and why something failed. Turn on Developer Mode in Settings
// to see a live trace of every Echo request. Nothing here leaves the phone.

nonisolated struct DevTrace: Identifiable, Hashable, Sendable {
    let id = UUID()
    let date = Date.now
    var feature: String          // Guide, Hey Echo, Agent, Skill, Shortcuts
    var engine: String           // Claude, Apple Intelligence, Keywords, Skill
    var input: String
    var outcome: String
    var latencyMs: Int
    var succeeded: Bool
    var hidden: [String] = []    // what Privacy Shield removed
    var payloadBytes: Int? = nil
    var usedPersonalContext = false
}

@Observable
@MainActor
final class DevInspector {
    static let shared = DevInspector()
    static let enabledKey = "echoDeveloperMode"

    private(set) var traces: [DevTrace] = []

    /// What Privacy Shield hid on the most recent screenshot (shown to everyone as a receipt).
    var lastHidden: [SensitiveKind] = []
    var lastHiddenAt: Date? = nil

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    func record(_ trace: DevTrace) {
        traces.insert(trace, at: 0)
        if traces.count > 100 { traces.removeLast(traces.count - 100) }
    }

    func noteShield(_ hidden: [SensitiveKind]) {
        lastHidden = hidden
        lastHiddenAt = .now
    }

    /// A one-line receipt like "Privacy Shield hid 1 card number before sending." (recent only)
    var recentShieldReceipt: String? {
        guard !lastHidden.isEmpty, let at = lastHiddenAt, Date.now.timeIntervalSince(at) < 300 else { return nil }
        let names = lastHidden.map(\.label).joined(separator: ", ")
        return "Privacy Shield hid your \(names) before anything left your iPhone."
    }

    func clear() { traces.removeAll() }

    nonisolated static func milliseconds(since start: ContinuousClock.Instant) -> Int {
        let d = ContinuousClock.now - start
        return Int(d.components.seconds * 1000 + d.components.attoseconds / 1_000_000_000_000_000)
    }

    /// Times an async call and records it.
    func measure<T>(feature: String, engine: String, input: String,
                    usedContext: Bool = false,
                    _ work: () async throws -> T,
                    describe: (T) -> String) async rethrows -> T {
        let start = ContinuousClock.now
        do {
            let value = try await work()
            let ms = Self.milliseconds(since: start)
            record(DevTrace(feature: feature, engine: engine, input: input, outcome: describe(value),
                            latencyMs: ms, succeeded: true,
                            hidden: lastHidden.map(\.label), usedPersonalContext: usedContext))
            return value
        } catch {
            let ms = Self.milliseconds(since: start)
            record(DevTrace(feature: feature, engine: engine, input: input, outcome: "Error: \(error.localizedDescription)",
                            latencyMs: ms, succeeded: false, usedPersonalContext: usedContext))
            throw error
        }
    }
}

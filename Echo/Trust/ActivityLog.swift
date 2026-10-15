import Foundation
import EventKit

// MARK: - Trust: "What Echo did" + Undo + how much Echo may do on its own
//
// Research (2026): 57% of people trust an AI more when they can undo what it
// did, and only about a third are comfortable letting an agent act for them.
// So Echo keeps a plain log of every action, lets you undo anything it created,
// and lets *you* decide how independent it is.

nonisolated enum UndoToken: Codable, Hashable, Sendable {
    case reminder(id: String)
    case event(id: String)
    case file(path: String)

    var label: String {
        switch self {
        case .reminder: return "Remove the reminder Echo made"
        case .event:    return "Remove the calendar event Echo made"
        case .file:     return "Remove the file Echo made"
        }
    }
}

nonisolated struct ActivityEntry: Codable, Identifiable, Hashable, Sendable {
    enum Status: String, Codable, Sendable { case done, handedOff, failed, undone }

    var id = UUID()
    var date = Date.now
    var batch: UUID
    var summary: String
    var icon: String
    var origin: String
    var status: Status
    var detail: String? = nil
    var undo: UndoToken? = nil

    var canUndo: Bool { undo != nil && status == .done }
}

@Observable
@MainActor
final class ActivityLog {
    static let shared = ActivityLog()
    private static let key = "echoActivityLog"
    private static let maxEntries = 200

    private(set) var entries: [ActivityEntry] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            entries = saved
        }
    }

    func record(_ entry: ActivityEntry) {
        entries.insert(entry, at: 0)
        if entries.count > Self.maxEntries { entries.removeLast(entries.count - Self.maxEntries) }
        save()
    }

    /// The most recent batch that still has something to undo.
    var lastUndoableBatch: UUID? {
        entries.first(where: \.canUndo)?.batch
    }

    func entries(in batch: UUID) -> [ActivityEntry] { entries.filter { $0.batch == batch } }

    /// Undo everything undoable in the latest batch. Returns a sentence for Echo to say.
    @discardableResult
    func undoLast() async -> String {
        guard let batch = lastUndoableBatch else { return "There's nothing for me to undo." }
        var undone = 0, failed = 0
        for entry in entries(in: batch) where entry.canUndo {
            if await undo(entry) { undone += 1 } else { failed += 1 }
        }
        if failed > 0 { return "I undid \(undone) and couldn't undo \(failed). Check the activity log." }
        return undone == 1 ? "Done — I undid that." : "Done — I undid those \(undone) things."
    }

    @discardableResult
    func undo(_ entry: ActivityEntry) async -> Bool {
        guard entry.canUndo, let token = entry.undo else { return false }
        do {
            try await Self.perform(token)
            if let i = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[i].status = .undone
                save()
            }
            return true
        } catch {
            if let i = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[i].detail = "Undo failed: \(error.localizedDescription)"
                save()
            }
            return false
        }
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    /// Only removes things Echo itself created moments/days ago — never your own data.
    private static func perform(_ token: UndoToken) async throws {
        switch token {
        case .reminder(let id):
            try await ReminderAgent().deleteReminder(calendarItemID: id)
        case .event(let id):
            try await ReminderAgent().deleteEvent(eventID: id)
        case .file(let path):
            try FileManager.default.removeItem(atPath: path)
        }
    }
}

// MARK: - Autonomy

enum EchoAutonomy: String, CaseIterable, Identifiable {
    case askEveryTime
    case autoSafe

    static let storageKey = "echoAutonomy"
    var id: String { rawValue }

    static var current: EchoAutonomy {
        EchoAutonomy(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .askEveryTime
    }

    var title: String {
        switch self {
        case .askEveryTime: return "Always ask me first"
        case .autoSafe:     return "Just do small, undoable things"
        }
    }

    var detail: String {
        switch self {
        case .askEveryTime: return "Echo shows its plan and waits for your OK every time."
        case .autoSafe:     return "Reminders, calendar events, notes, directions and websites happen right away — with Undo. Everything else still asks."
        }
    }

    /// May Echo run this plan without showing it first?
    static func canRunWithoutAsking(_ plan: AgentPlan) -> Bool {
        current == .autoSafe && !plan.actions.isEmpty && plan.actions.allSatisfy(\.isLowRisk)
    }
}

extension AgentAction {
    /// Creates something Echo can undo, or only opens an app. Never sends, calls, or deletes.
    var isLowRisk: Bool {
        switch self {
        case .createReminder, .createEvent, .createNote, .getDirections, .openWebsite: return true
        default: return false
        }
    }

    var isHandOff: Bool {
        switch self {
        case .sendMessage, .sendEmail, .callPhone, .getDirections, .runShortcut, .openWebsite, .createNote: return true
        default: return false
        }
    }
}

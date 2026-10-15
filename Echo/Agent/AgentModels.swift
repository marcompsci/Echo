import Foundation
import Contacts
import Photos
import EventKit

// MARK: - Agent request (natural language from the user)

struct AgentRequest: Sendable {
    let id: UUID
    let text: String
    let createdAt: Date

    init(text: String) {
        self.id = UUID()
        self.text = text
        self.createdAt = .now
    }
}

// MARK: - A concrete action Echo will take

enum AgentAction: Identifiable, Sendable {
    // Contacts
    case deleteContact(id: String, displayName: String)
    case createContact(givenName: String, familyName: String, phone: String?)

    // Photos
    case deletePhoto(localIdentifier: String, displayName: String)
    case createAlbum(name: String)

    // Files (in-app sandbox + iCloud)
    case createFile(name: String, directory: String, content: String)
    case deleteFile(path: String, displayName: String)
    case renameFile(path: String, newName: String)

    // Reminders
    case createReminder(title: String, dueDate: Date?)
    case deleteReminder(calendarItemID: String, title: String)

    // Notes (URL handoff — Notes has no public API)
    case createNote(title: String, body: String)

    // Calendar
    case createEvent(title: String, start: Date, end: Date)

    // Hand-offs: Echo fills everything in and opens the app; you tap Send/Call/Go.
    case sendMessage(recipient: String, body: String)
    case sendEmail(to: String, subject: String, body: String)
    case callPhone(recipient: String)
    case getDirections(destination: String)
    case runShortcut(name: String)
    case openWebsite(url: String)

    // Each action gets a stable ID derived from its payload
    var id: String {
        switch self {
        case .deleteContact(let id, _):      return "del-contact-\(id)"
        case .createContact(let g, let f, _): return "create-contact-\(g)-\(f)"
        case .deletePhoto(let id, _):        return "del-photo-\(id)"
        case .createAlbum(let name):         return "create-album-\(name)"
        case .createFile(let name, _, _):    return "create-file-\(name)"
        case .deleteFile(let path, _):       return "del-file-\(path)"
        case .renameFile(let path, _):       return "rename-\(path)"
        case .createReminder(let title, _):  return "create-reminder-\(title)"
        case .deleteReminder(let id, _):     return "del-reminder-\(id)"
        case .createNote(let title, _):      return "create-note-\(title)"
        case .createEvent(let title, let start, _): return "event-\(title)-\(start.timeIntervalSince1970)"
        case .sendMessage(let to, let body): return "msg-\(to)-\(body.hashValue)"
        case .sendEmail(let to, let subject, _): return "mail-\(to)-\(subject)"
        case .callPhone(let who):            return "call-\(who)"
        case .getDirections(let place):      return "maps-\(place)"
        case .runShortcut(let name):         return "shortcut-\(name)"
        case .openWebsite(let url):          return "web-\(url)"
        }
    }

    /// True for actions turned off in v1 (see FeatureFlags).
    var isBlockedInV1: Bool {
        switch self {
        case .deleteContact: return !FeatureFlags.allowsContactDeletion
        // Photos are only deleted from Photo Cleanup, where you pick each one.
        case .deletePhoto:   return true
        default: return false
        }
    }

    var isDestructive: Bool {
        switch self {
        case .deleteContact, .deletePhoto, .deleteFile, .deleteReminder: return true
        default: return false
        }
    }

    var icon: String {
        switch self {
        case .deleteContact, .createContact:        return "person.crop.circle"
        case .deletePhoto, .createAlbum:            return "photo"
        case .createFile, .deleteFile, .renameFile: return "doc"
        case .createReminder, .deleteReminder:      return "bell"
        case .createNote:                           return "note.text"
        case .createEvent:                          return "calendar.badge.plus"
        case .sendMessage:                          return "message"
        case .sendEmail:                            return "envelope"
        case .callPhone:                            return "phone"
        case .getDirections:                        return "map"
        case .runShortcut:                          return "square.stack.3d.up"
        case .openWebsite:                          return "safari"
        }
    }

    var summary: String {
        switch self {
        case .deleteContact(_, let name):       return "Delete contact: \(name)"
        case .createContact(let g, let f, _):   return "Create contact: \(g) \(f)"
        case .deletePhoto(_, let name):         return "Delete photo: \(name)"
        case .createAlbum(let name):            return "Create album: \(name)"
        case .createFile(let name, let dir, _): return "Create \(name) in \(dir)"
        case .deleteFile(_, let name):          return "Delete file: \(name)"
        case .renameFile(_, let name):          return "Rename to: \(name)"
        case .createReminder(let title, _):     return "Create reminder: \(title)"
        case .deleteReminder(_, let title):     return "Delete reminder: \(title)"
        case .createNote(let title, _):         return "Create note: \(title)"
        case .createEvent(let title, let start, _):
            return "Add to calendar: \(title), \(start.formatted(date: .abbreviated, time: .shortened))"
        case .sendMessage(let to, let body):    return "Text \(to): “\(body)” (you tap Send)"
        case .sendEmail(let to, let subject, _): return "Email \(to): \(subject) (you tap Send)"
        case .callPhone(let who):               return "Call \(who) (you confirm the call)"
        case .getDirections(let place):         return "Directions to \(place) in Maps"
        case .runShortcut(let name):            return "Run your shortcut “\(name)”"
        case .openWebsite(let url):             return "Open \(url)"
        }
    }

    var irreversibilityWarning: String? {
        switch self {
        case .deleteContact:
            return "Contact deletion cannot be undone unless you have an iCloud or vCard backup."
        case .deletePhoto:
            return "Deleted photos move to Recently Deleted and are permanently removed after 30 days."
        case .deleteFile:
            return "File deletion is permanent within the app sandbox."
        case .deleteReminder:
            return "Reminder deletion cannot be undone."
        default:
            return nil
        }
    }
}

// MARK: - A plan: what Echo proposes to do before asking for confirmation

struct AgentPlan: Identifiable, Sendable {
    let id: UUID
    let title: String
    let explanation: String
    let actions: [AgentAction]
    let safetyNotice: String?

    init(
        id: UUID = UUID(),
        title: String,
        explanation: String,
        actions: [AgentAction],
        safetyNotice: String? = nil
    ) {
        self.id = id
        self.title = title
        self.explanation = explanation
        self.actions = actions
        self.safetyNotice = safetyNotice
    }

    var hasDestructiveActions: Bool { actions.contains { $0.isDestructive } }

    /// Shown instead of a delete plan while photo/contact deletion is off in v1.
    static func deletionUnavailable(_ kind: String, appName: String) -> AgentPlan {
        AgentPlan(
            title: "Echo can't delete \(kind) yet",
            explanation: "To keep your \(kind) safe, this version of Echo doesn't delete them. You can remove them yourself in the \(appName) app — Echo can walk you through it if you send a screenshot.",
            actions: []
        )
    }
    var destructiveCount: Int { actions.filter { $0.isDestructive }.count }

    static let photoCleanupTitle = "Pick what to delete in Photo Cleanup"

    /// Voice never deletes photos directly: Echo opens Photo Cleanup so you choose each one.
    static var photoCleanupInstead: AgentPlan {
        AgentPlan(
            title: photoCleanupTitle,
            explanation: "I'll open Photo Cleanup so you can pick exactly which photos to delete. I'll ask once more before anything is deleted, and you can restore them for 30 days.",
            actions: []
        )
    }

    /// Echo never buys or pays for anything.
    static var purchaseRefused: AgentPlan {
        AgentPlan(
            title: "Echo doesn't buy things",
            explanation: "I never buy, order, or pay for anything for you. I can walk you through checking out yourself, or set a reminder.",
            actions: []
        )
    }
}

// MARK: - Result after execution

struct AgentResult: Identifiable, Sendable {
    let id: UUID
    let plan: AgentPlan
    let completedActions: [AgentAction]
    let failedActions: [(AgentAction, String)]
    let completedAt: Date

    init(plan: AgentPlan, completed: [AgentAction], failed: [(AgentAction, String)]) {
        self.id = UUID()
        self.plan = plan
        self.completedActions = completed
        self.failedActions = failed
        self.completedAt = .now
    }

    var isFullySuccessful: Bool { failedActions.isEmpty }
    var successCount: Int { completedActions.count }
    var failureCount: Int { failedActions.count }
}

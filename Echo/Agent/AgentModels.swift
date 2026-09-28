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
    var destructiveCount: Int { actions.filter { $0.isDestructive }.count }
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

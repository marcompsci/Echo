import Foundation
import FoundationModels

// MARK: - Echo Agent planner (Apple Intelligence)
//
// Turns a spoken/typed request ("remind me to pay my phone bill Friday")
// into a reviewable AgentPlan using the on-device model. The person always
// sees and confirms the plan before anything runs.
// Deleting photos or contacts is never planned in v1 (see FeatureFlags).

@Generable
nonisolated enum PlannedActionKind {
    case createReminder
    case createNote
    case createContact
    case createAlbum
    case createFolder
    case createCalendarEvent
    case sendText
    case sendEmail
    case callSomeone
    case getDirections
    case runShortcut
    case openWebsite
    case deletePhotosOrContacts
    case notSupported
}

@Generable
nonisolated struct PlannedAction {
    var kind: PlannedActionKind

    @Guide(description: "Reminder/event/note title, album or folder name, the contact's full name, the person to text/call/email, the destination, the shortcut name, or the website.")
    var title: String

    @Guide(description: "Note body, text message, or email body. Empty string if none.")
    var body: String

    @Guide(description: "Email subject, or the email address for an email. Empty string if not an email.")
    var subject: String

    @Guide(description: "Contact phone number if given, otherwise an empty string.")
    var phone: String

    @Guide(description: "Due date for a reminder or start time for an event as yyyy-MM-dd'T'HH:mm in the person's local time, or an empty string if none was mentioned.")
    var dueDate: String
}

@Generable
nonisolated struct PlannedAgentTask {
    @Guide(description: "Short title for the plan, e.g. 'Create reminder'.")
    var title: String

    @Guide(description: "One friendly sentence describing what Echo will do.")
    var explanation: String

    @Guide(description: "The actions needed, usually just one.")
    var actions: [PlannedAction]
}

struct OnDeviceAgentPlanner {

    func plan(for request: AgentRequest) async throws -> AgentPlan {
        let now = Date.now
        let today = now.formatted(.dateTime.weekday(.wide).year().month(.wide).day().hour().minute())

        let session = LanguageModelSession(instructions: """
            You plan simple phone tasks for Echo. Supported: create a reminder, create a note, \
            add a contact, create a photo album, create a folder in Echo's documents, add a \
            calendar event, write a text message, write an email, call someone, get directions, \
            run one of the person's Shortcuts by name, open a website. \
            If the person asks to delete or remove photos or contacts, use deletePhotosOrContacts. \
            Anything else is notSupported. Keep titles short and natural. \
            Today is \(today).
            \(EchoPersonalContext.text())
            """)

        let task = try await session.respond(to: request.text, generating: PlannedAgentTask.self).content

        if task.actions.contains(where: { $0.kind == .deletePhotosOrContacts }),
           !FeatureFlags.allowsPhotoAndContactDeletion {
            let mentionsContacts = request.text.lowercased().contains("contact")
            return mentionsContacts
                ? .deletionUnavailable("contacts", appName: "Contacts")
                : .deletionUnavailable("photos", appName: "Photos")
        }

        let actions = task.actions.prefix(5).compactMap { Self.agentAction(from: $0, fallbackText: request.text) }

        guard !actions.isEmpty else {
            return AgentPlan(
                title: "Echo can't do that yet",
                explanation: "Echo Agent can make reminders, notes, contacts, albums, folders, and calendar events, write texts and emails, start calls, get directions, run your Shortcuts, and open websites.",
                actions: []
            )
        }

        return AgentPlan(title: task.title, explanation: task.explanation, actions: Array(actions))
    }

    // MARK: - Mapping

    static func agentAction(from planned: PlannedAction, fallbackText: String) -> AgentAction? {
        let title = planned.title.trimmingCharacters(in: .whitespacesAndNewlines)
        switch planned.kind {
        case .createReminder:
            return .createReminder(title: title.isEmpty ? fallbackText : title, dueDate: parseDate(planned.dueDate))
        case .createNote:
            let body = planned.body.isEmpty ? fallbackText : planned.body
            return .createNote(title: title.isEmpty ? "Echo Note" : title, body: body)
        case .createContact:
            guard !title.isEmpty else { return nil }
            let parts = title.split(separator: " ", maxSplits: 1).map(String.init)
            let phone = planned.phone.trimmingCharacters(in: .whitespaces)
            return .createContact(givenName: parts.first ?? title,
                                  familyName: parts.count > 1 ? parts[1] : "",
                                  phone: phone.isEmpty ? nil : phone)
        case .createAlbum:
            return title.isEmpty ? nil : .createAlbum(name: title)
        case .createFolder:
            return title.isEmpty ? nil : .createFile(name: ".keep", directory: title, content: "")
        case .createCalendarEvent:
            guard !title.isEmpty, let start = parseDate(planned.dueDate) else { return nil }
            return .createEvent(title: title, start: start, end: start.addingTimeInterval(3600))
        case .sendText:
            guard !title.isEmpty else { return nil }
            return .sendMessage(recipient: title, body: planned.body)
        case .sendEmail:
            let address = planned.subject.contains("@") ? planned.subject : title
            return .sendEmail(to: address, subject: planned.subject.contains("@") ? "" : planned.subject, body: planned.body)
        case .callSomeone:
            return title.isEmpty ? nil : .callPhone(recipient: title)
        case .getDirections:
            return title.isEmpty ? nil : .getDirections(destination: title)
        case .runShortcut:
            return title.isEmpty ? nil : .runShortcut(name: title)
        case .openWebsite:
            return title.isEmpty ? nil : .openWebsite(url: title)
        case .deletePhotosOrContacts, .notSupported:
            return nil
        }
    }

    static func parseDate(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}

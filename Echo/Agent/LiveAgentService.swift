import Foundation
import Contacts

// MARK: - Live agent service — dispatches to real iOS APIs

struct LiveAgentService: AgentService {
    private let contacts  = ContactAgent()
    private let photos    = PhotoAgent()
    private let files     = FileAgent()
    private let reminders = ReminderAgent()

    // On-device NLP via EchoAIProcessor (CoreML + NaturalLanguage + Vision).
    // Replace with a backend call in LiveGuideService once an API is available.
    // Apple Intelligence plans the task on-device when available;
    // otherwise Echo falls back to its simple keyword parser.
    func analyze(request: AgentRequest) async throws -> AgentPlan {
        if AppleIntelligence.isAvailable {
            if let plan = try? await OnDeviceAgentPlanner().plan(for: request) {
                return plan
            }
        }
        return await EchoAIProcessor().processUserCommand(request.text)
    }

    // Execute dispatches each action to the appropriate native agent.
    func execute(plan: AgentPlan) async throws -> AgentResult {
        var completed: [AgentAction] = []
        var failed: [(AgentAction, String)] = []

        for action in plan.actions {
            do {
                try await dispatch(action)
                completed.append(action)
            } catch {
                failed.append((action, error.localizedDescription))
            }
        }

        return AgentResult(plan: plan, completed: completed, failed: failed)
    }

    // MARK: - Dispatch

    private func dispatch(_ action: AgentAction) async throws {
        guard !action.isBlockedInV1 else {
            throw EchoAgentError.executionFailed("This action isn't available in this version of Echo.")
        }
        switch action {

        // Contacts
        case .deleteContact(let id, _):
            try await contacts.delete(contactWithID: id)
        case .createContact(let given, let family, let phone):
            try await contacts.create(givenName: given, familyName: family, phone: phone)

        // Photos
        case .deletePhoto(let id, _):
            try await photos.delete(localIdentifiers: [id])
        case .createAlbum(let name):
            try await photos.createAlbum(named: name)

        // Files
        case .createFile(let name, _, let content):
            _ = try await files.createTextFile(name: name, content: content)
        case .deleteFile(let path, _):
            try await files.delete(path: path)
        case .renameFile(let path, let newName):
            _ = try await files.rename(path: path, to: newName)

        // Reminders
        case .createReminder(let title, let date):
            try await reminders.createReminder(title: title, dueDate: date)
        case .deleteReminder(let id, _):
            try await reminders.deleteReminder(calendarItemID: id)

        // Notes (URL scheme handoff — no public Notes API on iOS)
        case .createNote(let title, let body):
            await openNotesURL(title: title, body: body)

        // Calendar
        case .createEvent(let title, let start, let end):
            try await reminders.createEvent(title: title, start: start, end: end)

        // Hand-offs (iOS never lets an app send/call for you; the person taps)
        case .sendMessage(let recipient, let body):
            let address = await resolvePhone(recipient) ?? ""
            try await open("sms:\(address)&body=\(Self.encode(body))")
        case .sendEmail(let to, let subject, let body):
            try await open("mailto:\(to)?subject=\(Self.encode(subject))&body=\(Self.encode(body))")
        case .callPhone(let recipient):
            guard let number = await resolvePhone(recipient) else {
                throw EchoAgentError.notFound("A phone number for \(recipient)")
            }
            try await open("tel://\(number)")
        case .getDirections(let destination):
            try await open("maps://?daddr=\(Self.encode(destination))")
        case .runShortcut(let name):
            try await open("shortcuts://run-shortcut?name=\(Self.encode(name))")
        case .openWebsite(let url):
            let full = url.lowercased().hasPrefix("http") ? url : "https://\(url)"
            try await open(full)
        }
    }

    // MARK: - Hand-off helpers

    private static func encode(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=?+"))) ?? ""
    }

    @MainActor
    private func open(_ string: String) async throws {
        guard let url = URL(string: string) else { throw EchoAgentError.invalidInput(string) }
        let ok = await UIApplication.shared.open(url)
        if !ok { throw EchoAgentError.executionFailed("Couldn't open the app for this step.") }
    }

    /// A phone number as typed, or the first number of a matching contact.
    private func resolvePhone(_ recipient: String) async -> String? {
        let digits = recipient.filter { $0.isNumber || $0 == "+" }
        if digits.count >= 7 { return digits }
        guard let match = try? await contacts.search(query: recipient).first,
              let number = match.phoneNumbers.first?.value.stringValue else { return nil }
        return number.filter { $0.isNumber || $0 == "+" }
    }

    @MainActor
    private func openNotesURL(title: String, body: String) {
        let combined = "\(title)\n\n\(body)"
        let encoded  = combined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mobilenotes://new?body=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

import UIKit

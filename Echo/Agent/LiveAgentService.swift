import Foundation

// MARK: - Live agent service — dispatches to real iOS APIs

struct LiveAgentService: AgentService {
    private let contacts  = ContactAgent()
    private let photos    = PhotoAgent()
    private let files     = FileAgent()
    private let reminders = ReminderAgent()

    // Analyze is handled by the AI backend — this placeholder returns
    // a mock until a real backend is wired in.
    func analyze(request: AgentRequest) async throws -> AgentPlan {
        try await MockAgentService().analyze(request: request)
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
        }
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

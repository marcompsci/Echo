import Foundation

// MARK: - Core agent protocol

protocol AgentService: Sendable {
    /// Parse a natural language request into a proposed plan.
    func analyze(request: AgentRequest) async throws -> AgentPlan

    /// Execute a confirmed plan and return the result.
    func execute(plan: AgentPlan) async throws -> AgentResult
}

// MARK: - Mock agent service — works without any backend

struct MockAgentService: AgentService {
    func analyze(request: AgentRequest) async throws -> AgentPlan {
        try await Task.sleep(for: .seconds(1.2))
        return buildMockPlan(for: request.text)
    }

    func execute(plan: AgentPlan) async throws -> AgentResult {
        try await Task.sleep(for: .seconds(0.8))
        // Mock: all actions succeed
        return AgentResult(plan: plan, completed: plan.actions, failed: [])
    }

    // MARK: - Simple keyword intent router for demo

    private func buildMockPlan(for text: String) -> AgentPlan {
        let lower = text.lowercased()

        if lower.contains("contact") && (lower.contains("delete") || lower.contains("remove")) {
            return AgentPlan(
                title: "Delete matching contacts",
                explanation: "Echo found 3 contacts that match your description. Review them below before confirming.",
                actions: [
                    .deleteContact(id: "mock-1", displayName: "John Doe (2019)"),
                    .deleteContact(id: "mock-2", displayName: "Jane Smith (2019)"),
                    .deleteContact(id: "mock-3", displayName: "Bob Johnson (2019)")
                ],
                safetyNotice: "Deletion is permanent. Export a vCard backup first if you want to keep a record."
            )
        }

        if lower.contains("photo") && (lower.contains("delete") || lower.contains("remove") || lower.contains("clear")) {
            return AgentPlan(
                title: "Delete selected photos",
                explanation: "Echo found 12 screenshots from last month. Deleted items go to Recently Deleted for 30 days.",
                actions: [
                    .deletePhoto(localIdentifier: "mock-p1", displayName: "Screenshot 2025-08-01"),
                    .deletePhoto(localIdentifier: "mock-p2", displayName: "Screenshot 2025-08-03"),
                    .deletePhoto(localIdentifier: "mock-p3", displayName: "Screenshot 2025-08-07")
                ],
                safetyNotice: "Photos are recoverable from Recently Deleted for 30 days after deletion."
            )
        }

        if lower.contains("remind") || lower.contains("reminder") {
            return AgentPlan(
                title: "Create reminder",
                explanation: "Echo will add this to your Reminders app.",
                actions: [
                    .createReminder(title: text, dueDate: Calendar.current.date(byAdding: .day, value: 1, to: .now))
                ]
            )
        }

        if lower.contains("note") || lower.contains("write down") || lower.contains("save") {
            return AgentPlan(
                title: "Create note",
                explanation: "Echo will open Apple Notes and create a new note with your content.",
                actions: [
                    .createNote(title: "Echo note", body: text)
                ]
            )
        }

        if lower.contains("file") || lower.contains("create") || lower.contains("document") {
            return AgentPlan(
                title: "Create document",
                explanation: "Echo will create a new text file in your Echo documents folder.",
                actions: [
                    .createFile(name: "EchoDocument.txt", directory: "Echo Documents", content: text)
                ]
            )
        }

        // Default: show a plan with one info step
        return AgentPlan(
            title: "Task understood",
            explanation: "Echo is ready to help with: \"\(text)\". Connect a backend to enable full natural language parsing.",
            actions: [
                .createNote(title: "Echo Task", body: text)
            ]
        )
    }
}

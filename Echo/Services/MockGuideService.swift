import Foundation

// MARK: - Deterministic mock — fully functional without a backend

struct MockGuideService: GuideService {
    // Simulates analysis latency for a realistic experience
    private let delay: Duration = .seconds(1.8)

    func createGuide(imageData: Data, userQuestion: String) async throws -> GuideResponse {
        try await Task.sleep(for: delay)

        let steps: [GuideStep] = [
            GuideStep(
                number: 1,
                title: "Tap the highlighted option",
                detail: "It is the most likely place to continue from this screen."
            ),
            GuideStep(
                number: 2,
                title: "Review the choices",
                detail: "Look for wording that matches your goal before changing a setting."
            ),
            GuideStep(
                number: 3,
                title: "Confirm only if it looks right",
                detail: "You can return without saving if you are unsure."
            )
        ]

        let annotations: [Annotation] = [
            Annotation(
                type: .roundedRectangle,
                normalizedX: 0.10,
                normalizedY: 0.14,
                normalizedWidth: 0.80,
                normalizedHeight: 0.09,
                label: "1",
                colorStyle: .accent
            ),
            Annotation(
                type: .arrow,
                normalizedX: 0.47,
                normalizedY: 0.08,
                normalizedWidth: 0.06,
                normalizedHeight: 0.08,
                label: "",
                colorStyle: .accent
            )
        ]

        let actions: [ActionSuggestion] = [
            ActionSuggestion(
                title: "Save these steps to Notes",
                subtitle: "Keep a copy of this guide in Apple Notes.",
                systemImage: "note.text",
                actionType: .createNote,
                requiresConfirmation: true
            ),
            ActionSuggestion(
                title: "Create a reminder to finish later",
                subtitle: "Set a reminder so you can come back to this.",
                systemImage: "bell.badge",
                actionType: .createReminder,
                requiresConfirmation: true
            ),
            ActionSuggestion(
                title: "Share this guide",
                subtitle: "Send this guide to someone else.",
                systemImage: "square.and.arrow.up",
                actionType: .shareGuide,
                requiresConfirmation: false
            )
        ]

        return GuideResponse(
            summary: "Start with the option highlighted near the top of this screen.",
            safetyNotice: "Review the next screen before confirming any account or payment changes.",
            steps: steps,
            annotations: annotations,
            actionSuggestions: actions
        )
    }
}

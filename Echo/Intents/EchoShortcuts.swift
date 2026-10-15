import AppIntents

// MARK: - Siri phrases & Shortcuts actions
// Testing: Shortcuts app → + → search "Echo". Siri phrases need a real device.

struct EchoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: HeyEchoIntent(),
            phrases: [
                "Hey \(.applicationName)",
                "Talk to \(.applicationName)",
                "\(.applicationName), I need help"
            ],
            shortTitle: "Hey Echo",
            systemImageName: "circle.hexagongrid.circle"
        )
        AppShortcut(
            intent: AskEchoAboutLastScreenshotIntent(),
            phrases: [
                "Ask \(.applicationName) about my screenshot",
                "Ask \(.applicationName) about my screen",
                "\(.applicationName), what do I tap next"
            ],
            shortTitle: "Ask About Screenshot",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: StartLiveGuideIntent(),
            phrases: [
                "Start \(.applicationName) Live Guide",
                "\(.applicationName), watch my screen",
                "\(.applicationName), walk me through this"
            ],
            shortTitle: "Live Guide",
            systemImageName: "eye"
        )
        AppShortcut(
            intent: OpenEchoAgentIntent(),
            phrases: [
                "Open \(.applicationName) Agent",
                "Have \(.applicationName) do something"
            ],
            shortTitle: "Echo Agent",
            systemImageName: "wand.and.stars"
        )
        AppShortcut(
            intent: UndoEchoActionIntent(),
            phrases: [
                "Undo what \(.applicationName) did",
                "\(.applicationName), undo that"
            ],
            shortTitle: "Undo",
            systemImageName: "arrow.uturn.backward"
        )
        AppShortcut(
            intent: RememberWithEchoIntent(),
            phrases: [
                "\(.applicationName), remember something",
                "Add to \(.applicationName) memory"
            ],
            shortTitle: "Remember",
            systemImageName: "brain.head.profile"
        )
        AppShortcut(
            intent: AskEchoQuestionIntent(),
            phrases: [
                "Ask \(.applicationName) a question",
                "Quick question for \(.applicationName)"
            ],
            shortTitle: "Ask a Question",
            systemImageName: "questionmark.bubble"
        )
        AppShortcut(
            intent: AskEchoIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Open \(.applicationName)",
                "Get help from \(.applicationName)"
            ],
            shortTitle: "Ask Echo",
            systemImageName: "sparkles"
        )
    }
}

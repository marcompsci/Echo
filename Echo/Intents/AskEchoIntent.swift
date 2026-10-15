import AppIntents
import SwiftUI

// MARK: - Ask Echo (summon from Siri, Shortcuts, Action Button, Back Tap)

struct AskEchoIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Echo"
    static let description = IntentDescription(
        "Open Echo to create a visual guide from a screenshot or question.",
        categoryName: "Guide"
    )
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

/// Echo's "hotkey": take a screenshot, then run this (Action Button, Back Tap,
/// Control Center, or "Hey Siri, ask Echo about my screenshot").
struct AskEchoAboutLastScreenshotIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Echo About My Last Screenshot"
    static let description = IntentDescription(
        "Opens Echo with your most recent screenshot so you can ask what to do next.",
        categoryName: "Guide"
    )
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await EchoLaunchCenter.shared.request(.lastScreenshot)
        return .result()
    }
}

/// "Hey Siri, Hey Echo" · Action Button · Back Tap · Lock Screen control
struct HeyEchoIntent: AppIntent {
    static let title: LocalizedStringResource = "Hey Echo"
    static let description = IntentDescription(
        "Opens Echo already listening. Ask a question, get help with your screen, or have Echo do a task.",
        categoryName: "Guide"
    )
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await EchoLaunchCenter.shared.request(.heyEcho)
        return .result()
    }
}

struct StartLiveGuideIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Echo Live Guide"
    static let description = IntentDescription(
        "Opens Echo's Live Guide so Echo can watch your screen and talk you through a task.",
        categoryName: "Guide"
    )
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await EchoLaunchCenter.shared.request(.liveGuide)
        return .result()
    }
}

struct OpenEchoAgentIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Echo Agent"
    static let description = IntentDescription(
        "Ask Echo to create a reminder, note, contact, album, or folder.",
        categoryName: "Agent"
    )
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await EchoLaunchCenter.shared.request(.agent)
        return .result()
    }
}

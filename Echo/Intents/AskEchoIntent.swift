import AppIntents
import SwiftUI

// MARK: - Ask Echo App Intent

struct AskEchoIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Echo"
    static let description = IntentDescription(
        "Open Echo to create a visual guide from a screenshot or question.",
        categoryName: "Guide"
    )

    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // The intent opens the app; navigation to AnalyzeView is handled
        // by AppRouter once the app is in the foreground.
        return .result()
    }
}

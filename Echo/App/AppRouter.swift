import Foundation
import SwiftUI

// MARK: - App-wide navigation routes

enum EchoRoute: Hashable {
    case analyze
    case result
    case agent
    case liveGuide
    case heyEchoSetup
}

@Observable
@MainActor
final class AppRouter {
    var path = NavigationPath()

    // Shared state between Analyze → Result
    var pendingImageData: Data?      = nil
    var currentGuideResponse: GuideResponse? = nil
    var currentSession: EchoSession? = nil

    // Modal sheets
    var showSettings = false
    var showHeyEcho = false
    /// Spoken before Hey Echo starts listening (e.g. when you tap the pet).
    var heyEchoGreeting: String? = nil
    /// Goal handed to Live Guide (e.g. from Hey Echo).
    var pendingLiveGoal: String? = nil

    func navigateToAnalyze(imageData: Data) {
        pendingImageData = imageData
        path.append(EchoRoute.analyze)
    }

    func navigateToResult(session: EchoSession, response: GuideResponse) {
        currentSession       = session
        currentGuideResponse = response
        path.append(EchoRoute.result)
    }

    func navigateToAgent() {
        path.append(EchoRoute.agent)
    }

    func navigateToLiveGuide() {
        path.append(EchoRoute.liveGuide)
    }

    func popToHome() {
        path = NavigationPath()
        pendingImageData     = nil
        currentGuideResponse = nil
        currentSession       = nil
    }

    func popOne() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

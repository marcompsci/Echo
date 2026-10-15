import Foundation
import SwiftUI

// MARK: - App-wide navigation routes

enum EchoRoute: Hashable {
    case analyze
    case result
    case agent
    case liveGuide
    case heyEchoSetup
    case photoCleanup
    case fileCleanup
}

enum EchoTab: Hashable {
    case home, tools, activity, settings
}

@Observable
@MainActor
final class AppRouter {
    var path = NavigationPath()
    var selectedTab: EchoTab = .home

    // Shared state between Analyze → Result
    var pendingImageData: Data?      = nil
    var currentGuideResponse: GuideResponse? = nil
    var currentSession: EchoSession? = nil

    // Modal sheets
    /// Older call sites ask to "show settings" — that now switches to the Settings tab.
    var showSettings = false {
        didSet {
            if showSettings {
                selectedTab = .settings
                showSettings = false
            }
        }
    }
    var showHeyEcho = false
    /// Spoken before Hey Echo starts listening (e.g. when you tap the pet).
    var heyEchoGreeting: String? = nil
    /// A question or task handed to Hey Echo by a link, Shortcut, or Skill.
    var heyEchoText: String? = nil
    /// Goal handed to Live Guide (e.g. from Hey Echo).
    var pendingLiveGoal: String? = nil

    func navigateToAnalyze(imageData: Data) {
        selectedTab = .home
        pendingImageData = imageData
        path.append(EchoRoute.analyze)
    }

    func navigateToResult(session: EchoSession, response: GuideResponse) {
        currentSession       = session
        currentGuideResponse = response
        path.append(EchoRoute.result)
    }

    func navigateToAgent() {
        selectedTab = .home
        path.append(EchoRoute.agent)
    }

    func navigateToLiveGuide() {
        selectedTab = .home
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

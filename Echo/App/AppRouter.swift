import Foundation
import SwiftUI

// MARK: - App-wide navigation routes

enum EchoRoute: Hashable {
    case analyze
    case result
    case agent
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

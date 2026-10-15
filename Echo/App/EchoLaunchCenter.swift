import Foundation

// MARK: - Launch requests from outside the app
//
// Siri, Shortcuts, the Action Button, Control Center, and Visual Intelligence
// all open Echo with a request. HomeRootView watches this and routes.

enum EchoLaunchRequest: Equatable {
    case lastScreenshot          // "Ask Echo about my last screenshot"
    case capturedScreen(id: String)  // handed over by Visual Intelligence
    case agent                   // open Echo Agent
    case liveGuide               // open Live Guide (screen sharing)
    case heyEcho                 // open Echo already listening
}

@Observable
@MainActor
final class EchoLaunchCenter {
    static let shared = EchoLaunchCenter()
    var pending: EchoLaunchRequest? = nil

    func request(_ request: EchoLaunchRequest) { pending = request }

    /// echo://last-screenshot · echo://agent
    func handle(url: URL) -> Bool {
        guard url.scheme?.lowercased() == "echo" else { return false }
        switch url.host?.lowercased() {
        case "last-screenshot": pending = .lastScreenshot; return true
        case "agent":           pending = .agent; return true
        case "live":            pending = .liveGuide; return true
        case "hey":             pending = .heyEcho; return true
        default:                return false
        }
    }
}

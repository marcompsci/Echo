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
    case heyEchoWith(String)     // ask/do/remember/skill handed in by a link or Shortcut
    case liveGuideGoal(String)   // Live Guide with a goal
    case photoCleanup            // Photo Cleanup & Organizer
    case fileOrganizer           // File Cleanup & Organizer
    case connectAI               // Settings → Connect AI
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
        case "live":
            if let goal = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "goal" })?.value, !goal.isEmpty {
                pending = .liveGuideGoal(goal)
            } else {
                pending = .liveGuide
            }
            return true
        case "hey":             pending = .heyEcho; return true
        case "photos":          pending = .photoCleanup; return true
        case "files":           pending = .fileOrganizer; return true
        default:                break
        }
        // Developer hooks: echo://ask?q=…  echo://do?task=…  echo://remember?text=…
        //                  echo://live?goal=…  echo://skill?name=…
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            let v = items.first(where: { $0.name == name })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (v?.isEmpty ?? true) ? nil : v
        }
        switch url.host?.lowercased() {
        case "ask":
            guard let q = value("q") else { return false }
            pending = .heyEchoWith(q); return true
        case "do":
            guard let task = value("task") else { return false }
            pending = .heyEchoWith(task); return true
        case "remember":
            guard let text = value("text") else { return false }
            pending = .heyEchoWith("Remember " + text); return true
        case "skill":
            guard let name = value("name"),
                  let skill = EchoSkillStore.shared.skills.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }),
                  let phrase = skill.phrases.first else { return false }
            pending = .heyEchoWith(phrase); return true
        default:
            return false
        }
    }
}

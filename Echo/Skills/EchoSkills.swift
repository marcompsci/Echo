import Foundation

// MARK: - Echo Skills — your own commands
//
// "When I say ___, Echo does ___." Users and developers asked for custom
// skills: Echo matches your phrase on-device (instant, no AI guessing) and
// runs a Shortcut, opens a link or app, starts a Live Guide, asks Echo Agent,
// or just says something. Shortcuts makes this endlessly extensible.

nonisolated enum SkillAction: Codable, Hashable, Sendable {
    case say(String)
    case runShortcut(String)
    case openURL(String)
    case liveGuide(goal: String)
    case agent(request: String)

    var kindTitle: String {
        switch self {
        case .say: return "Say something"
        case .runShortcut: return "Run a Shortcut"
        case .openURL: return "Open a link or app"
        case .liveGuide: return "Walk me through"
        case .agent: return "Ask Echo Agent"
        }
    }

    var icon: String {
        switch self {
        case .say: return "text.bubble"
        case .runShortcut: return "square.stack.3d.up"
        case .openURL: return "link"
        case .liveGuide: return "dot.radiowaves.left.and.right"
        case .agent: return "wand.and.stars"
        }
    }

    var value: String {
        switch self {
        case .say(let v), .runShortcut(let v), .openURL(let v): return v
        case .liveGuide(let goal): return goal
        case .agent(let request): return request
        }
    }

    enum Kind: String, CaseIterable, Identifiable {
        case say, runShortcut, openURL, liveGuide, agent
        var id: String { rawValue }
        var title: String { make("").kindTitle }
        var placeholder: String {
            switch self {
            case .say: return "What Echo should say"
            case .runShortcut: return "Shortcut name, exactly as in Shortcuts"
            case .openURL: return "https://… or an app link like spotify:"
            case .liveGuide: return "What to walk you through"
            case .agent: return "e.g. remind me to stretch in 1 hour"
            }
        }
        func make(_ value: String) -> SkillAction {
            switch self {
            case .say: return .say(value)
            case .runShortcut: return .runShortcut(value)
            case .openURL: return .openURL(value)
            case .liveGuide: return .liveGuide(goal: value)
            case .agent: return .agent(request: value)
            }
        }
    }

    var kind: Kind {
        switch self {
        case .say: return .say
        case .runShortcut: return .runShortcut
        case .openURL: return .openURL
        case .liveGuide: return .liveGuide
        case .agent: return .agent
        }
    }
}

nonisolated struct EchoSkill: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var phrases: [String]
    var action: SkillAction
    var isEnabled = true
}

@Observable
@MainActor
final class EchoSkillStore {
    static let shared = EchoSkillStore()
    private static let key = "echoSkills"

    private(set) var skills: [EchoSkill] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([EchoSkill].self, from: data) {
            skills = saved
        }
    }

    func save(_ skill: EchoSkill) {
        var cleaned = skill
        cleaned.phrases = skill.phrases
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let i = skills.firstIndex(where: { $0.id == skill.id }) { skills[i] = cleaned } else { skills.append(cleaned) }
        persist()
    }

    func delete(_ skill: EchoSkill) {
        skills.removeAll { $0.id == skill.id }
        persist()
    }

    func toggle(_ skill: EchoSkill) {
        guard let i = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        skills[i].isEnabled.toggle()
        persist()
    }

    /// The enabled skill whose phrase best matches what was said (longest phrase wins).
    func match(_ said: String) -> EchoSkill? {
        let heard = Self.normalize(said)
        guard !heard.isEmpty else { return nil }
        var best: (skill: EchoSkill, length: Int)?
        for skill in skills where skill.isEnabled {
            for phrase in skill.phrases {
                let p = Self.normalize(phrase)
                guard !p.isEmpty else { continue }
                if heard == p || heard.hasPrefix(p + " ") || heard.hasSuffix(" " + p) || heard.contains(" " + p + " ") {
                    if best == nil || p.count > best!.length { best = (skill, p.count) }
                }
            }
        }
        return best?.skill
    }

    static func normalize(_ text: String) -> String {
        let lowered = text.lowercased()
            .replacingOccurrences(of: "hey echo", with: "")
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }
        return String(String.UnicodeScalarView(lowered))
            .split(separator: " ").joined(separator: " ")
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(skills) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    /// Starter ideas shown in the Skills screen.
    static let templates: [EchoSkill] = [
        EchoSkill(name: "Good morning", phrases: ["good morning"], action: .runShortcut("Good Morning")),
        EchoSkill(name: "Focus time", phrases: ["focus time", "i need to focus"], action: .agent(request: "Remind me to take a break in 50 minutes")),
        EchoSkill(name: "Play my music", phrases: ["play my music"], action: .openURL("music://")),
        EchoSkill(name: "Wi-Fi help", phrases: ["fix my wifi", "wifi help"], action: .liveGuide(goal: "Connect to a Wi-Fi network in Settings")),
        EchoSkill(name: "Bedtime", phrases: ["going to bed", "good night"], action: .runShortcut("Bedtime"))
    ]
}

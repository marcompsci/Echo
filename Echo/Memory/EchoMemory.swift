import Foundation

// MARK: - Echo Memory
//
// The #1 thing people ask AI assistants for: "remember me between chats."
// Echo's memory is:
//   • on this iPhone only (App Group storage, never synced to Echo's server)
//   • fully visible and editable in Settings → What Echo Remembers
//   • added only when you say "remember…" or type it yourself
//   • never allowed to hold card numbers, SSNs, passwords, or keys (Privacy Shield)
// Facts are shared with the AI only as short context for your own requests.

nonisolated struct MemoryFact: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var text: String
    var createdAt = Date.now
    var source: Source = .typed

    enum Source: String, Codable, Sendable { case typed, voice, shortcut }
}

nonisolated enum MemoryError: LocalizedError {
    case empty, sensitive(SensitiveKind), full

    var errorDescription: String? {
        switch self {
        case .empty: return "There's nothing to remember."
        case .sensitive(let kind): return "Echo never remembers a \(kind.label). Keep that in your password manager."
        case .full: return "Echo's memory is full. Remove something first."
        }
    }
}

@Observable
@MainActor
final class EchoMemory {
    static let shared = EchoMemory()

    nonisolated static let storageKey = "echoMemoryFacts"
    nonisolated static let enabledKey = "echoMemoryEnabled"
    static let maxFacts = 60

    private(set) var facts: [MemoryFact] = []

    var isEnabled: Bool {
        didSet { Self.store.set(isEnabled, forKey: Self.enabledKey) }
    }

    private init() {
        facts = Self.load()
        isEnabled = Self.store.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    // MARK: Edit

    @discardableResult
    func remember(_ raw: String, source: MemoryFact.Source = .typed) throws -> MemoryFact {
        let text = Self.clean(raw)
        guard !text.isEmpty else { throw MemoryError.empty }
        if let kind = PrivacyShield.kind(of: text) ?? Self.sensitiveWords(in: text) { throw MemoryError.sensitive(kind) }
        guard facts.count < Self.maxFacts else { throw MemoryError.full }
        if let existing = facts.first(where: { $0.text.caseInsensitiveCompare(text) == .orderedSame }) { return existing }
        let fact = MemoryFact(text: text, source: source)
        facts.insert(fact, at: 0)
        save()
        return fact
    }

    func update(_ fact: MemoryFact, text: String) throws {
        let cleaned = Self.clean(text)
        guard !cleaned.isEmpty else { throw MemoryError.empty }
        if let kind = PrivacyShield.kind(of: cleaned) ?? Self.sensitiveWords(in: cleaned) { throw MemoryError.sensitive(kind) }
        guard let i = facts.firstIndex(where: { $0.id == fact.id }) else { return }
        facts[i].text = cleaned
        save()
    }

    func forget(_ fact: MemoryFact) {
        facts.removeAll { $0.id == fact.id }
        save()
    }

    /// "Forget my gym" → removes facts that mention the words. Returns how many.
    @discardableResult
    func forget(matching query: String) -> Int {
        let words = query.lowercased().split(separator: " ").map(String.init).filter { $0.count > 2 && !["the", "that", "about", "my"].contains($0) }
        guard !words.isEmpty else { return 0 }
        let before = facts.count
        facts.removeAll { fact in words.allSatisfy { fact.text.lowercased().contains($0) } }
        save()
        return before - facts.count
    }

    func forgetAll() {
        facts.removeAll()
        save()
    }

    // MARK: Context for the AI

    /// A short, plain list for prompts. Empty when memory is off.
    nonisolated static func promptContext(limit: Int = 25) -> String {
        guard store.object(forKey: enabledKey) as? Bool ?? true else { return "" }
        let facts = load().prefix(limit)
        guard !facts.isEmpty else { return "" }
        return facts.map { "- \($0.text)" }.joined(separator: "\n")
    }

    // MARK: Storage

    nonisolated static var store: UserDefaults { EchoAppGroup.defaults ?? .standard }

    nonisolated static func load() -> [MemoryFact] {
        guard let data = store.data(forKey: storageKey),
              let facts = try? JSONDecoder().decode([MemoryFact].self, from: data) else { return [] }
        return facts
    }

    private func save() {
        if let data = try? JSONEncoder().encode(facts) { Self.store.set(data, forKey: Self.storageKey) }
    }

    nonisolated static func clean(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["remember that ", "remember ", "please remember ", "echo remember ", "don't forget "] {
            if text.lowercased().hasPrefix(prefix) { text = String(text.dropFirst(prefix.count)); break }
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " .,!"))
        guard let first = text.first else { return "" }
        return String(first).uppercased() + text.dropFirst().prefix(280)
    }

    nonisolated static func sensitiveWords(in text: String) -> SensitiveKind? {
        let lower = text.lowercased()
        if (lower.contains("password") || lower.contains("passcode") || lower.contains(" pin ")) && lower.contains(" is ") { return .password }
        if lower.contains("social security") && lower.contains(where: \.isNumber) { return .ssn }
        return nil
    }
}

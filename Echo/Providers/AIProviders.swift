import Foundation

// MARK: - Bring your own AI
//
// Connect your own Claude, ChatGPT, Grok, or Muse account with an API key
// and choose which AI handles which job. Keys live only in this iPhone's
// Keychain and go straight from your phone to that company — never to Echo's
// server. (Consumer subscriptions like ChatGPT Plus or Claude Pro can't be
// shared with other apps; each company's developer console issues the key.)

enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case echo          // Echo's own cloud (Claude via Echo's backend) — no key needed
    case apple         // Apple Intelligence, on-device — no key needed
    case claude        // Anthropic (Claude / Claude Code)
    case chatGPT       // OpenAI
    case grok          // xAI
    case muse          // Meta Muse Spark

    var id: String { rawValue }

    var name: String {
        switch self {
        case .echo:    return "Echo Cloud (Claude)"
        case .apple:   return "Apple Intelligence"
        case .claude:  return "Claude"
        case .chatGPT: return "ChatGPT"
        case .grok:    return "Grok"
        case .muse:    return "Muse"
        }
    }

    var company: String {
        switch self {
        case .echo:    return "Echo"
        case .apple:   return "Apple"
        case .claude:  return "Anthropic"
        case .chatGPT: return "OpenAI"
        case .grok:    return "xAI"
        case .muse:    return "Meta"
        }
    }

    var icon: String {
        switch self {
        case .echo:    return "circle.hexagongrid.circle"
        case .apple:   return "apple.intelligence"
        case .claude:  return "asterisk"
        case .chatGPT: return "bubble.left.and.text.bubble.right"
        case .grok:    return "bolt.horizontal"
        case .muse:    return "sparkle"
        }
    }

    /// Needs the person's own API key.
    var needsKey: Bool { ![.echo, .apple].contains(self) }

    var defaultModel: String {
        switch self {
        case .echo:    return "claude-sonnet-5-5"
        case .apple:   return "on-device"
        case .claude:  return "claude-sonnet-5-5"
        case .chatGPT: return "gpt-6-sol"
        case .grok:    return "grok-4.3"
        case .muse:    return "muse-spark-1.1"
        }
    }

    var defaultEndpoint: String {
        switch self {
        case .claude:  return "https://api.anthropic.com/v1/messages"
        case .chatGPT: return "https://api.openai.com/v1/chat/completions"
        case .grok:    return "https://api.x.ai/v1/chat/completions"
        case .muse:    return "https://api.meta.ai/v1/chat/completions"
        case .echo, .apple: return ""
        }
    }

    /// Where to create a key.
    var keyURL: URL? {
        switch self {
        case .claude:  return URL(string: "https://console.anthropic.com/settings/keys")
        case .chatGPT: return URL(string: "https://platform.openai.com/api-keys")
        case .grok:    return URL(string: "https://console.x.ai")
        case .muse:    return URL(string: "https://developers.meta.com")
        case .echo, .apple: return nil
        }
    }

    var strengths: String {
        switch self {
        case .echo:    return "Echo's default. Sees your screen, points at buttons, no setup."
        case .apple:   return "Private and free. Runs on your iPhone, works offline."
        case .claude:  return "Careful reasoning and coding help — great for app and developer errors."
        case .chatGPT: return "Strong all-rounder for questions, writing and images."
        case .grok:    return "Up-to-date, casual answers."
        case .muse:    return "Meta's assistant model (public preview, US only)."
        }
    }

    var keyPrefixHint: String {
        switch self {
        case .claude:  return "sk-ant-…"
        case .chatGPT: return "sk-…"
        case .grok:    return "xai-…"
        case .muse:    return "Meta API key"
        case .echo, .apple: return ""
        }
    }
}

/// Jobs you can assign to different AIs.
enum AITask: String, CaseIterable, Identifiable, Sendable {
    case screenHelp     // screenshots & guides
    case errorFixing    // Error Doctor
    case questions      // Hey Echo questions
    case writing        // drafting texts, emails, notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenHelp:  return "Screenshot help"
        case .errorFixing: return "Fixing errors"
        case .questions:   return "Questions"
        case .writing:     return "Writing"
        }
    }

    var icon: String {
        switch self {
        case .screenHelp:  return "camera.viewfinder"
        case .errorFixing: return "stethoscope"
        case .questions:   return "questionmark.bubble"
        case .writing:     return "pencil.line"
        }
    }

    var defaultProvider: AIProvider {
        switch self {
        case .screenHelp, .errorFixing: return .echo
        case .questions, .writing:      return .apple
        }
    }

    var storageKey: String { "aiRoute.\(rawValue)" }
}

// MARK: - Settings (keys in Keychain, everything else in UserDefaults)

enum AIConnections {

    static func key(for provider: AIProvider) -> String? {
        guard provider.needsKey else { return nil }
        let k = Keychain.read("ai.key.\(provider.rawValue)")
        return (k?.isEmpty ?? true) ? nil : k
    }

    static func setKey(_ key: String?, for provider: AIProvider) {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            Keychain.delete("ai.key.\(provider.rawValue)")
        } else {
            Keychain.save(trimmed, for: "ai.key.\(provider.rawValue)")
        }
    }

    static func isConnected(_ provider: AIProvider) -> Bool {
        switch provider {
        case .echo:  return true
        case .apple: return AppleIntelligence.isAvailable
        default:     return key(for: provider) != nil
        }
    }

    static func model(for provider: AIProvider) -> String {
        let stored = UserDefaults.standard.string(forKey: "ai.model.\(provider.rawValue)") ?? ""
        return stored.isEmpty ? provider.defaultModel : stored
    }

    static func setModel(_ model: String, for provider: AIProvider) {
        UserDefaults.standard.set(model.trimmingCharacters(in: .whitespaces), forKey: "ai.model.\(provider.rawValue)")
    }

    static func endpoint(for provider: AIProvider) -> String {
        let stored = UserDefaults.standard.string(forKey: "ai.endpoint.\(provider.rawValue)") ?? ""
        return stored.isEmpty ? provider.defaultEndpoint : stored
    }

    static func setEndpoint(_ endpoint: String, for provider: AIProvider) {
        UserDefaults.standard.set(endpoint.trimmingCharacters(in: .whitespaces), forKey: "ai.endpoint.\(provider.rawValue)")
    }

    /// Which AI handles a job. Falls back to Echo/Apple if the chosen one isn't connected.
    static func provider(for task: AITask) -> AIProvider {
        let chosen = AIProvider(rawValue: UserDefaults.standard.string(forKey: task.storageKey) ?? "") ?? task.defaultProvider
        if isConnected(chosen) { return chosen }
        return task.defaultProvider == .apple && !AppleIntelligence.isAvailable ? .echo : task.defaultProvider
    }

    static func setProvider(_ provider: AIProvider, for task: AITask) {
        UserDefaults.standard.set(provider.rawValue, forKey: task.storageKey)
    }
}

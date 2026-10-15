import Foundation
import AVFoundation

// MARK: - How Echo talks to *you*
//
// Voice choice, speed, Simple Mode (plain words, slower, bigger text — built for
// first-time smartphone users, older adults and anyone who wants calmer help),
// and keep-listening conversation mode. Plus the personal context every AI
// request carries: your name, your preferences, and what Echo remembers.

nonisolated enum EchoVoicePrefs {
    static let voiceKey = "echoVoiceIdentifier"
    static let rateKey = "echoSpeechRate"          // 0.7 … 1.3 (1 = normal)
    static let simpleModeKey = "echoSimpleMode"
    static let keepListeningKey = "echoKeepListening"

    static var voiceIdentifier: String? {
        let id = UserDefaults.standard.string(forKey: voiceKey) ?? ""
        return id.isEmpty ? nil : id
    }

    static var simpleMode: Bool { UserDefaults.standard.bool(forKey: simpleModeKey) }
    static var keepListening: Bool { UserDefaults.standard.bool(forKey: keepListeningKey) }

    static var rateMultiplier: Float {
        let stored = UserDefaults.standard.object(forKey: rateKey) as? Double ?? 1
        let base = Float(min(max(stored, 0.6), 1.4))
        return simpleMode ? base * 0.85 : base
    }

    /// The voice the person picked, or the best installed voice for their language.
    static func voice() -> AVSpeechSynthesisVoice? {
        if let id = voiceIdentifier, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        return bestDefaultVoice
    }

    /// Looking up every installed voice is slow, so do it once.
    private static let bestDefaultVoice: AVSpeechSynthesisVoice? = {
        let lang = AVSpeechSynthesisVoice.currentLanguageCode()
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == lang }
        return candidates.first(where: { $0.quality == .premium })
            ?? candidates.first(where: { $0.quality == .enhanced })
            ?? AVSpeechSynthesisVoice(language: lang)
    }()

    /// Installed voices for the person's language, best first.
    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        let prefix = String(AVSpeechSynthesisVoice.currentLanguageCode().prefix(2))
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) }
            .sorted { ($0.quality.rawValue, $0.name) > ($1.quality.rawValue, $1.name) }
    }
}

nonisolated enum EchoPersonalContext {

    /// Added to every Claude and Apple Intelligence request. Empty if there's nothing to say.
    static func text() -> String {
        var lines: [String] = []
        let name = (UserDefaults.standard.string(forKey: "userName") ?? "").trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { lines.append("The person's name is \(name).") }
        if EchoVoicePrefs.simpleMode {
            lines.append("Simple Mode is on: use plain, everyday words, no jargon, very short steps, and say exactly where things are on the screen (top right, bottom of the screen…).")
        }
        let memory = EchoMemory.promptContext()
        if !memory.isEmpty {
            lines.append("Things the person asked Echo to remember (use only when relevant):\n\(memory)")
        }
        return lines.joined(separator: "\n")
    }
}

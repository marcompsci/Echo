import Foundation
import FoundationModels

// MARK: - Apple Intelligence (on-device Foundation Models)
//
// Echo piggybacks on the Apple Intelligence model that ships with iOS.
// It runs on-device: free, private, and works offline. Echo uses it for:
//   • Planning Echo Agent tasks (replaces keyword matching)
//   • Fast/private guides from on-screen text when the cloud isn't used or is down
//   • Cleaning up voice transcripts
// Every caller must handle `isAvailable == false` (older iPhones, Apple
// Intelligence turned off, or the model still downloading).

enum AppleIntelligence {

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Plain-language status for Settings.
    static var statusDescription: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "On — Echo can use Apple Intelligence on this iPhone."
        case .unavailable(.deviceNotEligible):
            return "This iPhone doesn't support Apple Intelligence. Echo will use its cloud guide instead."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to let Echo work on-device."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading. Echo will use it once it's ready."
        case .unavailable:
            return "Apple Intelligence isn't available right now."
        }
    }

    /// Tidies a raw voice transcript (filler words, punctuation) without changing meaning.
    /// Returns the original text if Apple Intelligence is unavailable or anything fails.
    static func cleanUpTranscript(_ raw: String) async -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAvailable, text.count > 3 else { return text }
        do {
            let session = LanguageModelSession(instructions: """
                You clean up voice-dictated questions. Remove filler words (um, uh, like), \
                fix punctuation and obvious speech-recognition mistakes, keep the speaker's \
                meaning and wording otherwise. Reply with only the cleaned-up text.
                """)
            let response = try await session.respond(to: text)
            let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? text : cleaned
        } catch {
            return text
        }
    }
}

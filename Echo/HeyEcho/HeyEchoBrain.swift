import Foundation
import FoundationModels

// MARK: - What did they ask Hey Echo for?
//
// Apple Intelligence (on-device) sorts the request into one of four things
// and, for plain questions, writes a short spoken answer.

enum HeyEchoRoute: Equatable {
    case doTask(String)          // Echo Agent: plan → your permission → do it
    case helpWithScreen(String)  // open the latest screenshot with this question
    case walkMeThrough(String)   // Live Guide with this goal
    case answer(String)          // just say the answer
    case nothingHeard
}

@Generable
nonisolated enum HeyEchoKind {
    case doTask
    case helpWithScreen
    case walkMeThrough
    case question
}

@Generable
nonisolated struct HeyEchoDecision {
    @Guide(description: "doTask: they want Echo to make/send/call/schedule/open something. helpWithScreen: they ask about what's on their screen or a screenshot. walkMeThrough: they want step-by-step help doing something in an app or setting. question: anything else.")
    var kind: HeyEchoKind

    @Guide(description: "If kind is question: a friendly spoken answer in 1-3 short sentences. Otherwise an empty string.")
    var answer: String
}

struct HeyEchoBrain {

    func route(_ said: String) async -> HeyEchoRoute {
        let text = said.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .nothingHeard }

        if AppleIntelligence.isAvailable {
            do {
                let session = LanguageModelSession(instructions: """
                    You are Echo, a friendly iPhone assistant. Decide what the person wants. \
                    Today is \(Date.now.formatted(date: .complete, time: .shortened)).
                    """)
                let decision = try await session.respond(to: text, generating: HeyEchoDecision.self).content
                switch decision.kind {
                case .doTask:         return .doTask(text)
                case .helpWithScreen: return .helpWithScreen(text)
                case .walkMeThrough:  return .walkMeThrough(text)
                case .question:
                    let answer = decision.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                    return .answer(answer.isEmpty ? "Sorry, I'm not sure about that one." : answer)
                }
            } catch {
                // fall through to keywords
            }
        }
        return Self.keywordRoute(text)
    }

    /// Simple fallback when Apple Intelligence isn't available.
    static func keywordRoute(_ text: String) -> HeyEchoRoute {
        let lower = text.lowercased()
        let taskWords = ["remind", "text ", "message", "email", "call ", "directions", "navigate", "schedule",
                         "calendar", "add ", "create", "note", "shortcut", "open "]
        if taskWords.contains(where: lower.contains) { return .doTask(text) }
        if ["screen", "screenshot", "what do i tap", "this page", "this app"].contains(where: lower.contains) {
            return .helpWithScreen(text)
        }
        if ["how do i", "how to", "walk me", "help me", "show me how", "set up", "turn on", "turn off"].contains(where: lower.contains) {
            return .walkMeThrough(text)
        }
        return .answer("I can help with tasks, your screen, or step-by-step guides. Try “remind me…” or “walk me through…”.")
    }
}

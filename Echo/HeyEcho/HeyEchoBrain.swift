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
    case remember(String)        // "remember my gym is Crunch on Market St"
    case forget(String)          // "forget my gym"
    case undo                    // "undo that" / "take that back"
    case skill(EchoSkill)        // one of your own Echo Skills
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

/// Keeps the conversation going between turns, so follow-ups like
/// "and what about tomorrow?" work (people's #1 complaint: assistants forget).
@MainActor
final class HeyEchoBrain {

    private var session: LanguageModelSession?
    private var turns = 0
    private static let maxTurns = 8

    func resetConversation() {
        session = nil
        turns = 0
    }

    func route(_ said: String) async -> HeyEchoRoute {
        let text = said.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .nothingHeard }

        // Instant, on-device, no guessing: memory, undo, and your own Skills.
        if let direct = Self.directRoute(text) { return direct }
        if let skill = EchoSkillStore.shared.match(text) { return .skill(skill) }

        if AppleIntelligence.isAvailable {
            do {
                let session = currentSession()
                let decision = try await session.respond(to: text, generating: HeyEchoDecision.self).content
                turns += 1
                switch decision.kind {
                case .doTask:         return .doTask(text)
                case .helpWithScreen: return .helpWithScreen(text)
                case .walkMeThrough:  return .walkMeThrough(text)
                case .question:
                    let answer = decision.answer.trimmingCharacters(in: .whitespacesAndNewlines)
                    return .answer(answer.isEmpty ? "Sorry, I'm not sure about that one." : answer)
                }
            } catch {
                resetConversation()   // context window full or model busy — start fresh
            }
        }
        return Self.keywordRoute(text)
    }

    private func currentSession() -> LanguageModelSession {
        if let session, turns < Self.maxTurns { return session }
        turns = 0
        let fresh = LanguageModelSession(instructions: """
            You are Echo, a friendly iPhone assistant. Decide what the person wants. \
            Follow-up questions refer to earlier turns in this conversation. \
            If you don't know something or it needs live data (news, scores, prices), say so honestly \
            instead of guessing. Today is \(Date.now.formatted(date: .complete, time: .shortened)).
            \(EchoPersonalContext.text())
            """)
        session = fresh
        return fresh
    }

    /// Memory and undo commands, matched before any AI runs.
    static func directRoute(_ text: String) -> HeyEchoRoute? {
        let lower = text.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " .!?"))
        if ["undo", "undo that", "take that back", "never mind undo that", "undo it", "cancel that"].contains(lower) {
            return .undo
        }
        for prefix in ["remember that ", "remember ", "please remember ", "don't forget that "] where lower.hasPrefix(prefix) {
            let fact = String(text.dropFirst(prefix.count))
            if fact.lowercased().hasPrefix("to ") { return .doTask("Remind me " + fact) }  // "remember to buy milk"
            return fact.isEmpty ? nil : .remember(fact)
        }
        for prefix in ["forget about ", "forget that ", "forget "] where lower.hasPrefix(prefix) {
            let what = String(text.dropFirst(prefix.count))
            return what.isEmpty ? nil : .forget(what)
        }
        return nil
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

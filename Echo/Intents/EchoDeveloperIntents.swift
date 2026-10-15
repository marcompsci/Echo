import AppIntents
import FoundationModels

// MARK: - Echo as a building block (Shortcuts, Siri, other apps)
//
// Developers and power users asked for assistants that plug into their own
// workflows. These actions run without opening Echo and return results that
// any Shortcut can pass to the next step.

struct AskEchoQuestionIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Echo a Question"
    static let description = IntentDescription(
        "Echo answers with Apple Intelligence on your iPhone, using what you've asked it to remember. Returns the answer as text.",
        categoryName: "Developer"
    )
    static let openAppWhenRun = false

    @Parameter(title: "Question", requestValueDialog: "What do you want to ask Echo?")
    var question: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Echo \(\.$question)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let answer = await Self.answer(question)
        return .result(value: answer, dialog: IntentDialog(stringLiteral: answer))
    }

    @MainActor
    static func answer(_ question: String) async -> String {
        guard AppleIntelligence.isAvailable else {
            return "Turn on Apple Intelligence to ask Echo questions from Shortcuts."
        }
        let start = ContinuousClock.now
        do {
            let session = LanguageModelSession(instructions: """
                You are Echo, a friendly iPhone assistant. Answer in 1-3 short sentences. \
                If you don't know or it needs live data, say so honestly. \
                Today is \(Date.now.formatted(date: .complete, time: .shortened)).
                \(EchoPersonalContext.text())
                """)
            let text = try await session.respond(to: question).content
            DevInspector.shared.record(DevTrace(feature: "Shortcuts", engine: "Apple Intelligence", input: question,
                                                outcome: String(text.prefix(80)), latencyMs: DevInspector.milliseconds(since: start),
                                                succeeded: true))
            return text
        } catch {
            return "Echo couldn't answer that right now."
        }
    }
}

struct RememberWithEchoIntent: AppIntent {
    static let title: LocalizedStringResource = "Remember with Echo"
    static let description = IntentDescription(
        "Adds something to What Echo Remembers. Stays on this iPhone. Echo refuses card numbers, passwords and other secrets.",
        categoryName: "Developer"
    )
    static let openAppWhenRun = false

    @Parameter(title: "Text", requestValueDialog: "What should Echo remember?")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Echo, remember \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let fact = try EchoMemory.shared.remember(text, source: .shortcut)
            return .result(dialog: IntentDialog(stringLiteral: "Got it. I'll remember: \(fact.text)"))
        } catch {
            return .result(dialog: IntentDialog(stringLiteral: error.localizedDescription))
        }
    }
}

struct UndoEchoActionIntent: AppIntent {
    static let title: LocalizedStringResource = "Undo Echo's Last Action"
    static let description = IntentDescription(
        "Removes the reminder, calendar event, or file Echo most recently created.",
        categoryName: "Developer"
    )
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let sentence = await ActivityLog.shared.undoLast()
        return .result(dialog: IntentDialog(stringLiteral: sentence))
    }
}

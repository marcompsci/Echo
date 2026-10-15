import Foundation
import FoundationModels

// MARK: - Error Doctor
//
// Drop a screenshot with an error on it and Echo:
//   1. spots the error text on-device (OCR + Privacy Shield),
//   2. answers instantly from what it already knows about iOS errors,
//   3. asks the AI you chose for "Fixing errors" (Apple Intelligence, Echo Cloud,
//      Claude, ChatGPT, Grok or Muse) for the exact cause and fix,
//   4. offers to fix it — and only does so after you say yes.

nonisolated enum ErrorDetector {
    static let signals = [
        "error", "failed", "failure", "couldn't", "could not", "can't", "cannot", "unable to", "not available",
        "denied", "invalid", "expired", "try again", "went wrong", "not connected", "offline", "declined",
        "not trusted", "untrusted", "storage full", "not enough", "problem", "unexpectedly", "crash", "exception",
        "timed out", "not found", "404", "500", "403", "401", "locked", "disabled", "unsupported", "incorrect"
    ]

    /// Lines on screen that look like an error message, most error-like first. Empty = no error.
    static func errorLines(in lines: [String]) -> [String] {
        let scored = lines.compactMap { line -> (String, Int)? in
            let lower = line.lowercased()
            let score = signals.filter { lower.contains($0) }.count
            return score > 0 ? (line, score) : nil
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(6).map(\.0)
    }
}

@Generable
nonisolated enum AIFixKind {
    case storage, permission, network, settingsChange, signIn, appProblem, payment, developerCode, other
}

@Generable
nonisolated struct AIDiagnosis {
    @Guide(description: "Short plain title of the problem, e.g. 'Your iPhone is out of space'.")
    var title: String
    @Guide(description: "One or two plain sentences: why this error happened.")
    var cause: String
    @Guide(description: "2 to 5 short steps that fix it, in order.")
    var steps: [String]
    @Guide(description: "Which kind of fix this needs.")
    var fixKind: AIFixKind
    @Guide(description: "If fixing it means changing something in Settings or an app, a short goal for a walk-through like 'Turn on Developer Mode in Settings'. Otherwise empty.")
    var walkthroughGoal: String
}

/// Same shape, decoded from Claude / ChatGPT / Grok / Muse JSON.
nonisolated struct AIDiagnosisJSON: Decodable {
    var title: String
    var cause: String
    var steps: [String]
    var fixKind: String?
    var walkthroughGoal: String?

    var diagnosis: AIDiagnosis {
        let kind: AIFixKind
        switch (fixKind ?? "").lowercased() {
        case "storage": kind = .storage
        case "permission": kind = .permission
        case "network": kind = .network
        case "settingschange", "settings": kind = .settingsChange
        case "signin": kind = .signIn
        case "appproblem", "app": kind = .appProblem
        case "payment": kind = .payment
        case "developercode", "developer", "code": kind = .developerCode
        default: kind = .other
        }
        return AIDiagnosis(title: title, cause: cause, steps: steps, fixKind: kind, walkthroughGoal: walkthroughGoal ?? "")
    }
}

@MainActor
struct ErrorDoctor {

    /// Fast pass: is there an error, and does Echo already know it?
    static func quickLook(imageData: Data) async -> (lines: [String], known: ErrorDiagnosis?, prepared: PreparedGuideImage?) {
        guard let prepared = try? await Task.detached(priority: .userInitiated, operation: {
            try ScreenTextReader.prepare(imageData, maxElements: 120)
        }).value else { return ([], nil, nil) }

        let all = prepared.elements.map(\.text)
        let lines = ErrorDetector.errorLines(in: all)
        let known = ErrorKnowledge.match(all.joined(separator: "\n")).map {
            ErrorDiagnosis(title: $0.title, cause: $0.cause, steps: $0.steps, fixes: $0.fixes,
                           source: "Echo's built-in iPhone know-how", errorText: lines.first ?? "")
        }
        return (lines, known, prepared)
    }

    /// Deeper pass with the AI chosen for "Fixing errors".
    static func diagnose(prepared: PreparedGuideImage, errorLines: [String], known: ErrorDiagnosis?) async throws -> ErrorDiagnosis {
        let provider = AIConnections.provider(for: .errorFixing)
        let screenText = prepared.elements.map(\.text).joined(separator: "\n")
        let system = """
            You are Echo, an expert iPhone and app troubleshooter (iOS, apps, Wi-Fi, Apple Account, Xcode and \
            developer errors too). Read the error on this screenshot, explain in plain words WHY it happened, and give \
            the exact steps to fix it. Never ask for passwords or codes. Never suggest buying anything unless it is \
            truly the only fix, and say the person decides. \(EchoPersonalContext.text())
            """
        let prompt = """
            Error text found on screen:
            \(errorLines.joined(separator: "\n"))

            All text on the screen:
            \(screenText.prefix(3000))
            \(known.map { "\nEcho thinks this may be: \($0.title)." } ?? "")
            """
        let start = ContinuousClock.now
        let result: AIDiagnosis
        var engine = provider.name

        switch provider {
        case .apple:
            guard AppleIntelligence.isAvailable else { throw EchoError.analysisUnavailable }
            let session = LanguageModelSession(instructions: system)
            result = try await session.respond(to: prompt, generating: AIDiagnosis.self).content
        case .echo:
            // Echo Cloud: the guide backend sees the image itself.
            let guide = try await LiveGuideService().createGuide(
                imageData: prepared.jpegData,
                userQuestion: "There's an error on this screen: \"\(errorLines.first ?? "")\". Explain why it happened and exactly how to fix it.")
            engine = "Echo Cloud (Claude)"
            result = AIDiagnosis(title: known?.title ?? "What this error means",
                                 cause: guide.summary,
                                 steps: guide.steps.map { $0.detail.isEmpty ? $0.title : "\($0.title). \($0.detail)" },
                                 fixKind: .other, walkthroughGoal: "")
        default:
            let json = system + """

                JSON shape: {"title": string, "cause": string, "steps": [string], \
                "fixKind": "storage|permission|network|settingsChange|signIn|appProblem|payment|developerCode|other", \
                "walkthroughGoal": string}
                """
            result = try await ExternalAIClient(provider: provider)
                .completeJSON(AIDiagnosisJSON.self, system: json, prompt: prompt, imageJPEG: prepared.jpegData).diagnosis
        }

        DevInspector.shared.record(DevTrace(feature: "Error Doctor", engine: engine, input: errorLines.first ?? "",
                                            outcome: result.title, latencyMs: DevInspector.milliseconds(since: start),
                                            succeeded: true, hidden: prepared.hidden.map(\.label)))

        var fixes = known?.fixes ?? []
        fixes.append(contentsOf: Self.fixes(for: result.fixKind, goal: result.walkthroughGoal))
        var unique: [FixAction] = []
        for f in fixes where !unique.contains(f) { unique.append(f) }

        return ErrorDiagnosis(title: result.title, cause: result.cause, steps: Array(result.steps.prefix(5)),
                              fixes: Array(unique.prefix(3)), source: engine, errorText: errorLines.first ?? "")
    }

    static func fixes(for kind: AIFixKind, goal: String) -> [FixAction] {
        let walk: [FixAction] = goal.trimmingCharacters(in: .whitespaces).isEmpty ? [] : [.liveGuide(goal: goal)]
        switch kind {
        case .storage:    return [.freeUpStorage] + walk
        case .permission: return [.openEchoSettings] + walk
        default:          return walk
        }
    }
}

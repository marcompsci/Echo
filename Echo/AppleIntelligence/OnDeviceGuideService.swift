import Foundation
import FoundationModels

// MARK: - On-device guide (Apple Intelligence)
//
// Reads the screenshot's text on-device (Vision OCR), then asks the Apple
// Intelligence model what to tap. Markers come from the exact OCR boxes, so
// they land on real buttons. Nothing leaves the phone.
// Limitation: the on-device model reads text, not pixels — icons without a
// label can't be pointed at. The cloud guide (Claude) handles those.

@Generable
nonisolated struct OnDeviceGuide {
    @Guide(description: "One or two friendly, plain-language sentences answering the question.")
    var summary: String

    @Guide(description: "Only if the screen clearly shows a scam, phishing, a fake virus alert, or a request for a gift card, payment, password, or code from someone else: a short warning. Otherwise an empty string. Normal sign-in or settings screens are NOT scams.")
    var safetyNotice: String

    @Guide(description: "Between 1 and 5 short steps, in order.")
    var steps: [OnDeviceStep]
}

@Generable
nonisolated struct OnDeviceStep {
    @Guide(description: "Short action, e.g. 'Tap Wi-Fi'.")
    var title: String

    @Guide(description: "One sentence of extra help.")
    var detail: String

    @Guide(description: "The id (like e12) of the on-screen text to tap for this step, or an empty string if the step happens on a later screen.")
    var elementID: String
}

struct OnDeviceGuideService: GuideService {

    func createGuide(imageData: Data, userQuestion: String) async throws -> GuideResponse {
        guard AppleIntelligence.isAvailable else { throw EchoError.analysisUnavailable }

        let prepared: PreparedGuideImage
        do {
            prepared = try await Task.detached(priority: .userInitiated) {
                try ScreenTextReader.prepare(imageData, maxElements: 80)
            }.value
        } catch {
            throw EchoError.imageProcessingFailed
        }

        let screenText = prepared.elements.isEmpty
            ? "No text was found on this screen."
            : prepared.elements
                .map { "\($0.id): \"\($0.text)\" (\(Self.region(for: $0)))" }
                .joined(separator: "\n")

        let session = LanguageModelSession(instructions: """
            You are Echo, a calm helper for people who are stuck on their iPhone. \
            You are given the text found on a screenshot (each with an id and rough position) \
            and the person's question. Explain in plain words with no jargon, then give \
            1 to 5 short steps. When a step means tapping something listed on this screen, \
            set elementID to that item's id — only if that item's text is what the step tells \
            them to tap. Steps that happen on a later screen get an empty elementID. \
            Never use the same id for two steps. Never invent buttons that aren't listed. \
            Never tell anyone to share a password, verification code, or card number.
            """)

        let prompt = """
            Question: \(userQuestion)

            Text on the screen:
            \(screenText)
            """

        let guide: OnDeviceGuide
        do {
            guide = try await session.respond(to: prompt, generating: OnDeviceGuide.self).content
        } catch {
            throw EchoError.analysisUnavailable
        }

        return Self.makeResponse(from: guide, elements: prepared.elements)
    }

    // MARK: - Mapping

    static func makeResponse(from guide: OnDeviceGuide, elements: [ScreenTextElement]) -> GuideResponse {
        let byID = Dictionary(elements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let steps = guide.steps.prefix(5).enumerated().map { index, step in
            GuideStep(number: index + 1, title: step.title, detail: step.detail)
        }

        let pad = 0.012
        var annotations: [Annotation] = []
        var usedIDs = Set<String>()
        for (index, step) in guide.steps.prefix(5).enumerated() {
            let id = step.elementID.trimmingCharacters(in: .whitespaces)
            guard let el = byID[id], !usedIDs.contains(id),
                  Self.step(step, mentions: el.text) else { continue }
            usedIDs.insert(id)
            let x = max(0, el.x - pad), y = max(0, el.y - pad)
            annotations.append(Annotation(
                type: .roundedRectangle,
                normalizedX: x,
                normalizedY: y,
                normalizedWidth: min(1 - x, el.width + pad * 2),
                normalizedHeight: min(1 - y, el.height + pad * 2),
                label: String(index + 1),
                colorStyle: .accent
            ))
        }

        // The small on-device model sometimes writes "this isn't a scam" style notes; drop those.
        var notice = guide.safetyNotice.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = notice.lowercased()
        if ["don't worry", "do not worry", "not a scam", "no risk", "nothing risky", "looks safe", "is safe"]
            .contains(where: lowered.contains) {
            notice = ""
        }
        return GuideResponse(
            summary: guide.summary,
            safetyNotice: notice.isEmpty ? nil : notice,
            steps: Array(steps),
            annotations: annotations,
            actionSuggestions: [
                ActionSuggestion(
                    title: "Share this guide",
                    subtitle: "Send these steps to someone else.",
                    systemImage: "square.and.arrow.up",
                    actionType: .shareGuide,
                    requiresConfirmation: false
                )
            ]
        )
    }

    /// Keeps a marker only when the step actually refers to that on-screen text,
    /// so a wrong id from the model doesn't put a marker on an unrelated row.
    static func step(_ step: OnDeviceStep, mentions elementText: String) -> Bool {
        let stepText = (step.title + " " + step.detail).lowercased()
        let words = elementText.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
        guard !words.isEmpty else { return false }
        return words.contains { stepText.contains($0) }
    }

    private static func region(for el: ScreenTextElement) -> String {
        let vertical = el.y < 0.33 ? "top" : (el.y < 0.66 ? "middle" : "bottom")
        let midX = el.x + el.width / 2
        let horizontal = midX < 0.33 ? "left" : (midX < 0.66 ? "center" : "right")
        return "\(vertical) \(horizontal)"
    }
}

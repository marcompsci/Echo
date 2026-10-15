import Foundation

// MARK: - Screenshot guides from the AI you connected

nonisolated struct ExternalGuideJSON: Decodable, Sendable {
    struct Step: Decodable, Sendable { var title: String; var detail: String?; var elementID: String? }
    var summary: String
    var safetyNotice: String?
    var steps: [Step]
}

struct ExternalGuideService: GuideService {
    let provider: AIProvider

    func createGuide(imageData: Data, userQuestion: String) async throws -> GuideResponse {
        let prepared: PreparedGuideImage
        do {
            prepared = try await Task.detached(priority: .userInitiated) {
                try ScreenTextReader.prepare(imageData)
            }.value
        } catch {
            throw EchoError.imageProcessingFailed
        }
        DevInspector.shared.noteShield(prepared.hidden)

        let screenText = prepared.elements
            .map { "\($0.id): \"\($0.text)\" at x=\(String(format: "%.2f", $0.x)) y=\(String(format: "%.2f", $0.y))" }
            .joined(separator: "\n")

        let system = """
            You are Echo, a calm helper for people stuck on their iPhone. You see a screenshot and the \
            text found on it (with ids and positions, 0-1 from the top-left). Explain in plain words, then \
            give 1-5 short steps. If a step means tapping a listed item, set elementID to its id; otherwise "". \
            Never tell anyone to share a password, code or card number. If something looks like a scam, say so in safetyNotice.
            JSON shape: {"summary": string, "safetyNotice": string or null, "steps": [{"title": string, "detail": string, "elementID": string}]}
            \(EchoPersonalContext.text())
            """
        let prompt = "Question: \(userQuestion)\n\nText on the screen:\n\(screenText.isEmpty ? "(none found)" : screenText)"

        let json = try await ExternalAIClient(provider: provider)
            .completeJSON(ExternalGuideJSON.self, system: system, prompt: prompt, imageJPEG: prepared.jpegData)

        let guide = OnDeviceGuide(
            summary: json.summary,
            safetyNotice: json.safetyNotice ?? "",
            steps: json.steps.prefix(5).map {
                OnDeviceStep(title: $0.title, detail: $0.detail ?? "", elementID: $0.elementID ?? "")
            }
        )
        return OnDeviceGuideService.makeResponse(from: guide, elements: prepared.elements)
    }
}

import Foundation

struct GuideResponse: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let summary: String
    let safetyNotice: String?
    let steps: [GuideStep]
    let annotations: [Annotation]
    let actionSuggestions: [ActionSuggestion]

    init(
        id: UUID = UUID(),
        summary: String,
        safetyNotice: String? = nil,
        steps: [GuideStep] = [],
        annotations: [Annotation] = [],
        actionSuggestions: [ActionSuggestion] = []
    ) {
        self.id = id
        self.summary = summary
        self.safetyNotice = safetyNotice
        self.steps = steps
        self.annotations = annotations
        self.actionSuggestions = actionSuggestions
    }

    var encodedData: Data? {
        try? JSONEncoder().encode(self)
    }
}

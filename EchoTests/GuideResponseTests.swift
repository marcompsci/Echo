import Testing
import Foundation
@testable import Echo

// MARK: - GuideResponse JSON decoding

@Suite("GuideResponse Decoding")
struct GuideResponseTests {

    @Test("Decodes a complete GuideResponse from JSON")
    func decodeCompleteResponse() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "summary": "Tap the button at the top.",
            "safetyNotice": "Review before confirming.",
            "steps": [
                {
                    "id": "00000000-0000-0000-0000-000000000002",
                    "number": 1,
                    "title": "Tap the button",
                    "detail": "It is highlighted in blue."
                }
            ],
            "annotations": [
                {
                    "id": "00000000-0000-0000-0000-000000000003",
                    "type": "roundedRectangle",
                    "normalizedX": 0.1,
                    "normalizedY": 0.2,
                    "normalizedWidth": 0.5,
                    "normalizedHeight": 0.1,
                    "label": "1",
                    "colorStyle": "accent"
                }
            ],
            "actionSuggestions": [
                {
                    "id": "00000000-0000-0000-0000-000000000004",
                    "title": "Save to Notes",
                    "subtitle": "Keep a copy.",
                    "systemImage": "note.text",
                    "actionType": "createNote",
                    "requiresConfirmation": true
                }
            ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GuideResponse.self, from: json)

        #expect(response.summary == "Tap the button at the top.")
        #expect(response.safetyNotice == "Review before confirming.")
        #expect(response.steps.count == 1)
        #expect(response.steps[0].number == 1)
        #expect(response.steps[0].title == "Tap the button")
        #expect(response.annotations.count == 1)
        #expect(response.annotations[0].type == .roundedRectangle)
        #expect(response.annotations[0].colorStyle == .accent)
        #expect(response.actionSuggestions.count == 1)
        #expect(response.actionSuggestions[0].actionType == .createNote)
        #expect(response.actionSuggestions[0].requiresConfirmation == true)
    }

    @Test("Decodes GuideResponse with no safety notice")
    func decodeWithoutSafetyNotice() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000005",
            "summary": "Simple summary.",
            "steps": [],
            "annotations": [],
            "actionSuggestions": []
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GuideResponse.self, from: json)

        #expect(response.safetyNotice == nil)
        #expect(response.steps.isEmpty)
    }

    @Test("Round-trips through encode and decode")
    func roundTrip() throws {
        let original = GuideResponse(
            id: UUID(),
            summary: "Test summary",
            safetyNotice: "Test notice",
            steps: [GuideStep(number: 1, title: "Do this", detail: "Because of that")],
            annotations: [],
            actionSuggestions: []
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GuideResponse.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.summary == original.summary)
        #expect(decoded.safetyNotice == original.safetyNotice)
        #expect(decoded.steps.count == original.steps.count)
        #expect(decoded.steps[0].title == original.steps[0].title)
    }

    @Test("MockGuideService returns deterministic output")
    func mockServiceDeterministic() async throws {
        let service = MockGuideService()
        let data = Data("test".utf8)

        let r1 = try await service.createGuide(imageData: data, userQuestion: "q1")
        let r2 = try await service.createGuide(imageData: data, userQuestion: "q2")

        // Summary is constant regardless of question
        #expect(r1.summary == r2.summary)
        #expect(r1.steps.count == r2.steps.count)
        #expect(r1.annotations.count == r2.annotations.count)
        #expect(r1.actionSuggestions.count == r2.actionSuggestions.count)
    }

    @Test("MockGuideService steps are numbered 1-based sequentially")
    func mockServiceStepNumbering() async throws {
        let service = MockGuideService()
        let response = try await service.createGuide(imageData: Data(), userQuestion: "test")

        for (idx, step) in response.steps.enumerated() {
            #expect(step.number == idx + 1)
        }
    }
}

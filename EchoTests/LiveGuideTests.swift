import Testing
import Foundation
@testable import Echo

// MARK: - Backend response + v1 safety

@Suite("Live guide backend")
struct LiveGuideBackendTests {

    @Test("Decodes the exact JSON shape the echo-guide function returns")
    func decodesBackendResponse() throws {
        let json = """
        {
          "id": "24d8ca19-bacc-47f5-817e-47d2f87e22ef",
          "summary": "Turn on Wi-Fi from Settings.",
          "safetyNotice": null,
          "steps": [
            {"id": "764f0f3b-dc75-4573-8b78-f5d675a55520", "number": 1, "title": "Tap Wi-Fi", "detail": "It's near the top."}
          ],
          "annotations": [
            {"id": "41c17f6e-13a6-4616-a938-c75bea2fb113", "type": "roundedRectangle",
             "normalizedX": 0.088, "normalizedY": 0.188, "normalizedWidth": 0.174, "normalizedHeight": 0.054,
             "label": "1", "colorStyle": "accent"}
          ],
          "actionSuggestions": [
            {"id": "57e5cf38-44c8-4042-a60c-d0b72f8108f5", "title": "Open Settings", "subtitle": "Go straight there",
             "systemImage": "gear", "actionType": "openSettings", "requiresConfirmation": true}
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(GuideResponse.self, from: json)
        #expect(response.steps.count == 1)
        #expect(response.annotations.first?.label == "1")
        #expect(response.safetyNotice == nil)
        #expect(response.actionSuggestions.first?.actionType == .openSettings)
    }

    @Test("Request body encodes OCR elements for the backend")
    func encodesRequest() throws {
        let prepared = PreparedGuideImage(
            jpegData: Data([0xFF, 0xD8]),
            pixelWidth: 1179,
            pixelHeight: 2556,
            elements: [ScreenTextElement(id: "e1", text: "Wi-Fi", x: 0.1, y: 0.2, width: 0.15, height: 0.03)]
        )
        let body = GuideAPIRequest(prepared: prepared, userQuestion: "How do I turn on Wi-Fi?")
        let data = try JSONEncoder().encode(body)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["mediaType"] as? String == "image/jpeg")
        #expect((object["elements"] as? [[String: Any]])?.count == 1)
    }
}

@Suite("Safety: deletions only from a reviewed selection")
struct DeletionDisabledTests {

    @Test("Delete actions are blocked")
    func deleteActionsBlocked() {
        #expect(FeatureFlags.allowsContactDeletion == false)
        #expect(FeatureFlags.allowsPurchases == false)
        // Photos are deleted only from Photo Cleanup, never straight from a voice plan.
        #expect(AgentAction.deletePhoto(localIdentifier: "x", displayName: "x").isBlockedInV1)
        #expect(AgentAction.deleteContact(id: "x", displayName: "x").isBlockedInV1)
        #expect(!AgentAction.createAlbum(name: "Receipts").isBlockedInV1)
    }

    @Test("On-device parser never plans a contact or photo deletion")
    func parserReturnsNoDeletePlan() async {
        let processor = EchoAIProcessor()
        for command in ["Delete duplicate contacts", "Clear old screenshots from my photos", "remove the photo of my receipt"] {
            let plan = await processor.processUserCommand(command)
            #expect(plan.actions.isEmpty, "\(command) should not produce actions")
        }
    }

    @Test("Executing a delete action fails safely instead of deleting")
    func executeRefusesDelete() async throws {
        let plan = AgentPlan(
            title: "Test",
            explanation: "Test",
            actions: [.deletePhoto(localIdentifier: "fake-id", displayName: "Screenshot")]
        )
        let result = try await LiveAgentService().execute(plan: plan)
        #expect(result.completedActions.isEmpty)
        #expect(result.failureCount == 1)
    }
}

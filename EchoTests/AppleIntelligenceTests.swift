import Testing
import Foundation
@testable import Echo

@Suite("Apple Intelligence mapping")
struct AppleIntelligenceMappingTests {

    private let elements = [
        ScreenTextElement(id: "e1", text: "Settings", x: 0.1, y: 0.05, width: 0.3, height: 0.04),
        ScreenTextElement(id: "e2", text: "Wi-Fi", x: 0.1, y: 0.30, width: 0.2, height: 0.03),
        ScreenTextElement(id: "e3", text: "Passcode", x: 0.1, y: 0.90, width: 0.2, height: 0.03)
    ]

    @Test("Markers only land on text the step actually mentions, once each")
    func markersAreValidated() {
        let guide = OnDeviceGuide(
            summary: "Turn on Wi-Fi.",
            safetyNotice: "",
            steps: [
                OnDeviceStep(title: "Tap Wi-Fi", detail: "It's near the top.", elementID: "e2"),
                OnDeviceStep(title: "Enter your password", detail: "On the next screen.", elementID: "e3"),
                OnDeviceStep(title: "Tap Wi-Fi again", detail: "", elementID: "e2")
            ]
        )
        let response = OnDeviceGuideService.makeResponse(from: guide, elements: elements)
        #expect(response.steps.count == 3)
        #expect(response.annotations.count == 1)
        #expect(response.annotations.first?.label == "1")
        #expect(response.safetyNotice == nil)
    }

    @Test("Reassuring 'not a scam' notes are dropped")
    func dropsFalseSafetyNotice() {
        let guide = OnDeviceGuide(summary: "x", safetyNotice: "This looks like a scam, but don't worry.", steps: [])
        #expect(OnDeviceGuideService.makeResponse(from: guide, elements: []).safetyNotice == nil)
    }

    @Test("Agent planner maps reminders with due dates")
    func plannerMapsReminder() {
        let planned = PlannedAction(kind: .createReminder, title: "Pay phone bill", body: "", subject: "", phone: "", dueDate: "2026-10-16T09:00")
        guard case .createReminder(let title, let due)? = OnDeviceAgentPlanner.agentAction(from: planned, fallbackText: "x") else {
            Issue.record("Expected a reminder"); return
        }
        #expect(title == "Pay phone bill")
        #expect(due != nil)
    }

    @Test("Agent planner never maps deletions")
    func plannerSkipsDeletion() {
        let planned = PlannedAction(kind: .deletePhotosOrContacts, title: "old screenshots", body: "", subject: "", phone: "", dueDate: "")
        #expect(OnDeviceAgentPlanner.agentAction(from: planned, fallbackText: "x") == nil)
    }
}

@Suite("Agent hand-off actions")
struct AgentHandoffTests {
    @Test("Planner maps texts, calls, directions and events")
    func mapsNewKinds() {
        let text = PlannedAction(kind: .sendText, title: "Mom", body: "On my way", subject: "", phone: "", dueDate: "")
        guard case .sendMessage(let to, let body)? = OnDeviceAgentPlanner.agentAction(from: text, fallbackText: "") else {
            Issue.record("Expected a text"); return
        }
        #expect(to == "Mom" && body == "On my way")

        let event = PlannedAction(kind: .createCalendarEvent, title: "Dentist", body: "", subject: "", phone: "", dueDate: "2026-10-20T15:30")
        guard case .createEvent(_, let start, let end)? = OnDeviceAgentPlanner.agentAction(from: event, fallbackText: "") else {
            Issue.record("Expected an event"); return
        }
        #expect(end.timeIntervalSince(start) == 3600)

        let noTime = PlannedAction(kind: .createCalendarEvent, title: "Dentist", body: "", subject: "", phone: "", dueDate: "")
        #expect(OnDeviceAgentPlanner.agentAction(from: noTime, fallbackText: "") == nil)
    }

    @Test("Hand-off actions are never destructive or blocked")
    func handoffsAreSafe() {
        let actions: [AgentAction] = [
            .sendMessage(recipient: "Mom", body: "hi"), .callPhone(recipient: "Mom"),
            .getDirections(destination: "Ferry Building"), .runShortcut(name: "Home")
        ]
        #expect(actions.allSatisfy { !$0.isDestructive && !$0.isBlockedInV1 })
    }
}

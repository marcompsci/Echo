import Testing
import Foundation
@testable import Echo

@Suite("Privacy Shield")
struct PrivacyShieldTests {

    @Test("Finds valid card numbers, ignores random digits")
    func cards() {
        #expect(PrivacyShield.kind(of: "4242 4242 4242 4242") == .cardNumber)
        #expect(PrivacyShield.kind(of: "Card 5555-5555-5555-4444") == .cardNumber)
        #expect(PrivacyShield.kind(of: "1234 5678 9012 3456") == nil)   // fails Luhn
        #expect(PrivacyShield.kind(of: "Order #10293") == nil)
    }

    @Test("Finds SSNs and secret keys")
    func ssnAndKeys() {
        #expect(PrivacyShield.kind(of: "123-45-6789") == .ssn)
        #expect(PrivacyShield.kind(of: "sk-ant-api03-abcdefghijklmnop") == .apiKey)
        #expect(PrivacyShield.kind(of: "Hello world") == nil)
    }

    @Test("Hides the value next to a Password label, not the label")
    func passwordField() {
        let boxes = [
            ShieldTextBox(text: "Password", x: 0.1, y: 0.40, width: 0.2, height: 0.03),
            ShieldTextBox(text: "hunter2!!", x: 0.4, y: 0.40, width: 0.2, height: 0.03),
            ShieldTextBox(text: "Forgot password?", x: 0.1, y: 0.50, width: 0.3, height: 0.03)
        ]
        let result = PrivacyShield.scan(boxes)
        #expect(result.hidden == [1: .password])
    }

    @Test("Bank numbers only when labeled")
    func bank() {
        #expect(PrivacyShield.kind(of: "000123456789", label: "Account number") == .bankNumber)
        #expect(PrivacyShield.kind(of: "000123456789", label: "Tracking") == nil)
    }
}

@Suite("Memory, Skills, and Hey Echo commands")
@MainActor
struct AssistantCommandTests {

    @Test("Memory cleans phrasing and refuses secrets")
    func memoryCleaning() {
        #expect(EchoMemory.clean("remember that my gym is Crunch.") == "My gym is Crunch")
        #expect(EchoMemory.sensitiveWords(in: "my bank password is fish") == .password)
    }

    @Test("Remember / forget / undo route instantly")
    func directRoutes() {
        #expect(HeyEchoBrain.directRoute("Remember my gym is Crunch") == .remember("my gym is Crunch"))
        #expect(HeyEchoBrain.directRoute("remember to buy milk") == .doTask("Remind me to buy milk"))
        #expect(HeyEchoBrain.directRoute("Forget my gym") == .forget("my gym"))
        #expect(HeyEchoBrain.directRoute("Undo that.") == .undo)
        #expect(HeyEchoBrain.directRoute("What's the weather") == nil)
    }

    @Test("Skill phrases are normalized")
    func skillNormalize() {
        #expect(EchoSkillStore.normalize("Hey Echo, Good Morning!") == "good morning")
    }

    @Test("Only small, undoable actions can skip the permission prompt")
    func lowRisk() {
        #expect(AgentAction.createReminder(title: "x", dueDate: nil).isLowRisk)
        #expect(!AgentAction.sendMessage(recipient: "Mom", body: "hi").isLowRisk)
        #expect(!AgentAction.createContact(givenName: "A", familyName: "B", phone: nil).isLowRisk)
    }
}

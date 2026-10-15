import Testing
import Foundation
@testable import Echo

@Suite("Error Doctor")
struct ErrorDoctorTests {

    @Test("Finds error lines and ignores normal text")
    func detectsErrors() {
        let lines = ["Settings", "Wi-Fi", "Unable to join the network “Home”", "Cancel"]
        #expect(ErrorDetector.errorLines(in: lines) == ["Unable to join the network “Home”"])
        #expect(ErrorDetector.errorLines(in: ["Photos", "Albums", "For You"]).isEmpty)
    }

    @Test("Knows common iPhone errors instantly")
    func knowledge() {
        #expect(ErrorKnowledge.match("Untrusted Developer\nYour device management settings…")?.id == "untrusted-developer")
        #expect(ErrorKnowledge.match("Storage Almost Full\nManage")?.id == "storage-full")
        #expect(ErrorKnowledge.match("Cannot Verify Server Identity")?.id == "server-identity")
        #expect(ErrorKnowledge.match("Good morning! 3 new messages") == nil)
    }

    @Test("Storage problems offer Photo Cleanup as a fix")
    func storageFix() {
        #expect(ErrorKnowledge.match("iPhone Storage Full")?.fixes.contains(.freeUpStorage) == true)
    }
}

@Suite("Permission & purchases")
@MainActor
struct PermissionTests {

    @Test("Echo refuses purchases")
    func purchases() {
        #expect(PurchaseGuard.isPurchaseRequest("Buy me AirPods"))
        #expect(PurchaseGuard.isPurchaseRequest("pay my phone bill"))
        #expect(!PurchaseGuard.isPurchaseRequest("What's a good tip for 4 people?"))
        #expect(HeyEchoBrain.directRoute("order a pizza") == .refusePurchase)
    }

    @Test("Deleting photos by voice opens Photo Cleanup instead")
    func photoCleanupRoute() {
        #expect(HeyEchoBrain.directRoute("Delete my old screenshots") == .photoCleanup)
        #expect(HeyEchoBrain.directRoute("organize my files") == .fileCleanup)
        #expect(AgentAction.deletePhoto(localIdentifier: "x", displayName: "x").isBlockedInV1)
    }

    @Test("Files are sorted by type")
    func fileKinds() {
        #expect(FileKind.of(URL(fileURLWithPath: "/a/b.jpg")) == .images)
        #expect(FileKind.of(URL(fileURLWithPath: "/a/b.pdf")) == .documents)
        #expect(FileKind.of(URL(fileURLWithPath: "/a/b.mov")) == .videos)
        #expect(FileKind.of(URL(fileURLWithPath: "/a/b.zip")) == .archives)
    }

    @Test("Connected-AI replies are parsed for both API styles")
    func parseReplies() {
        let anthropic: [String: Any] = ["content": [["type": "text", "text": "connected"]]]
        let openAI: [String: Any] = ["choices": [["message": ["content": "connected"]]]]
        #expect(ExternalAIClient.text(from: anthropic, anthropic: true) == "connected")
        #expect(ExternalAIClient.text(from: openAI, anthropic: false) == "connected")
    }
}

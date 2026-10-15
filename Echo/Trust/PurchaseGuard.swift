import Foundation

// MARK: - Echo never buys anything
//
// There is no purchase action anywhere in Echo. This catches requests like
// "buy…", "order…", "pay for…" so Echo says so clearly instead of trying.

nonisolated enum PurchaseGuard {
    static let phrases = ["buy ", "purchase", "order me", "order a ", "order an ", "place an order", "checkout", "check out my cart",
                          "pay for", "pay my", "make a payment", "send money", "transfer money", "subscribe to",
                          "add to cart", "venmo", "cash app", "zelle", "apple pay"]

    static func isPurchaseRequest(_ text: String) -> Bool {
        let lower = " " + text.lowercased() + " "
        // Reminders, notes and lists *about* buying are fine ("remind me to buy milk").
        if ["remind", "remember", "note", "list", "how do i", "how to", "what is", "what's"].contains(where: lower.contains) { return false }
        return phrases.contains { lower.contains($0) }
    }
}

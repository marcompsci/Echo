import Foundation
import UIKit

// MARK: - Image safety hints (client-side, non-authoritative)
// Connect to a server-side content-moderation endpoint before shipping
// any automated sensitive-content detection.

struct ImageSafetyService: Sendable {
    // Returns a privacy reminder for screenshot-shaped images.
    // This is a UX hint, not a content filter.
    func sensitiveContentWarning(for imageData: Data) -> String? {
        guard let image = UIImage(data: imageData) else { return nil }
        let size = image.size
        guard size.width > 0 else { return nil }
        let ratio = size.height / size.width
        // Portrait screenshot proportions typically have ratio > 1.6
        if ratio > 1.6 {
            return "Before sharing: remove passwords, private messages, payment details, or anything you do not want analyzed."
        }
        return nil
    }

    // Placeholder — always returns false in MVP.
    func containsSensitiveContent(_ imageData: Data) async -> Bool {
        false
    }
}

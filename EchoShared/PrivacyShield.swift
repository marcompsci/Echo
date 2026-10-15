import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Vision

// MARK: - Privacy Shield
//
// Runs on-device BEFORE a screenshot or live frame leaves the phone.
// Finds card numbers, Social Security numbers, bank/routing numbers,
// passwords and API keys in the on-screen text, blacks them out in the
// image, and replaces the text Echo sends with a placeholder.
// The AI never sees them. Shared by the app and the Live Guide extension.

nonisolated enum SensitiveKind: String, Codable, Sendable, CaseIterable {
    case cardNumber, ssn, bankNumber, password, apiKey

    var placeholder: String {
        switch self {
        case .cardNumber: return "[card number hidden by Echo]"
        case .ssn:        return "[SSN hidden by Echo]"
        case .bankNumber: return "[account number hidden by Echo]"
        case .password:   return "[password hidden by Echo]"
        case .apiKey:     return "[secret key hidden by Echo]"
        }
    }

    var label: String {
        switch self {
        case .cardNumber: return "card number"
        case .ssn:        return "Social Security number"
        case .bankNumber: return "bank number"
        case .password:   return "password"
        case .apiKey:     return "secret key"
        }
    }
}

/// A piece of on-screen text with a top-left-origin, 0–1 normalized box.
nonisolated struct ShieldTextBox: Sendable {
    let text: String
    let x: Double, y: Double, width: Double, height: Double
}

nonisolated struct ShieldResult: Sendable {
    /// Indexes (into the boxes passed in) that were hidden, with what they were.
    let hidden: [Int: SensitiveKind]
    var count: Int { hidden.count }
    var kinds: [SensitiveKind] { Array(Set(hidden.values)).sorted { $0.rawValue < $1.rawValue } }
}

nonisolated enum PrivacyShield {

    static let enabledKey = "privacyShieldEnabled"

    /// On by default. Stored in the App Group so the Live Guide extension follows it too.
    static var isEnabled: Bool {
        let store = EchoAppGroup.defaults ?? .standard
        return store.object(forKey: enabledKey) as? Bool ?? true
    }

    static func setEnabled(_ on: Bool) {
        (EchoAppGroup.defaults ?? .standard).set(on, forKey: enabledKey)
    }

    // MARK: Detection

    private static let secretLabels = ["password", "passcode", "passwort", "contraseña", "pin", "cvv", "cvc", "security code"]
    private static let bankLabels = ["account number", "acct", "routing", "iban", "account #", "acct #"]

    /// What kind of secret this text is, if any. `label` is the nearest text before it on screen.
    static func kind(of text: String, label: String? = nil) -> SensitiveKind? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowerLabel = (label ?? "").lowercased()

        if containsSSN(trimmed) { return .ssn }
        if containsCardNumber(trimmed) { return .cardNumber }
        if looksLikeAPIKey(trimmed) { return .apiKey }

        let digits = trimmed.filter(\.isNumber)
        let mostlyDigits = digits.count >= 6 && Double(digits.count) / Double(trimmed.count) > 0.7
        if mostlyDigits, digits.count <= 17, bankLabels.contains(where: lowerLabel.contains) { return .bankNumber }

        // A short value right after a "Password"/"PIN" label, or masked dots.
        if trimmed.allSatisfy({ "•●*·".contains($0) }) && trimmed.count >= 4 { return nil } // already masked by iOS
        if secretLabels.contains(where: lowerLabel.hasSuffix) || secretLabels.contains(where: { lowerLabel == $0 || lowerLabel == $0 + ":" }) {
            if !trimmed.contains(" "), trimmed.count >= 4, trimmed.count <= 64,
               !secretLabels.contains(where: trimmed.lowercased().contains) { return .password }
        }
        return nil
    }

    static func scan(_ boxes: [ShieldTextBox]) -> ShieldResult {
        var hidden: [Int: SensitiveKind] = [:]
        for (index, box) in boxes.enumerated() {
            let label = nearestLabel(for: index, in: boxes)
            if let kind = kind(of: box.text, label: label) { hidden[index] = kind }
        }
        return ShieldResult(hidden: hidden)
    }

    /// The closest text above or to the left of a box (the field's label).
    private static func nearestLabel(for index: Int, in boxes: [ShieldTextBox]) -> String? {
        let target = boxes[index]
        var best: (distance: Double, text: String)?
        for (i, other) in boxes.enumerated() where i != index {
            let sameRowLeft = abs(other.y - target.y) < max(target.height, 0.012) && other.x + other.width <= target.x + 0.01
            let above = other.y < target.y && target.y - (other.y + other.height) < 0.05 && abs(other.x - target.x) < 0.25
            guard sameRowLeft || above else { continue }
            let d = hypot(other.x - target.x, other.y - target.y)
            if best == nil || d < best!.distance { best = (d, other.text) }
        }
        return best?.text
    }

    static func containsSSN(_ text: String) -> Bool {
        text.range(of: #"\b\d{3}[- ]\d{2}[- ]\d{4}\b"#, options: .regularExpression) != nil
    }

    static func containsCardNumber(_ text: String) -> Bool {
        guard let range = text.range(of: #"(?:\d[ -]?){13,19}"#, options: .regularExpression) else { return false }
        let digits = text[range].filter(\.isNumber)
        return (13...19).contains(digits.count) && luhn(String(digits))
    }

    static func luhn(_ digits: String) -> Bool {
        var sum = 0
        for (i, ch) in digits.reversed().enumerated() {
            guard var n = ch.wholeNumberValue else { return false }
            if i % 2 == 1 { n *= 2; if n > 9 { n -= 9 } }
            sum += n
        }
        return sum % 10 == 0
    }

    static func looksLikeAPIKey(_ text: String) -> Bool {
        let prefixes = ["sk-", "sk_live_", "sk_test_", "sb_secret_", "ghp_", "gho_", "github_pat_", "xox", "AKIA", "AIza"]
        if prefixes.contains(where: text.hasPrefix), text.count >= 16 { return true }
        // Long random-looking token: 32+ chars, no spaces, letters + digits mixed.
        guard text.count >= 32, !text.contains(" ") else { return false }
        let letters = text.filter(\.isLetter).count, digits = text.filter(\.isNumber).count
        return letters > 8 && digits > 6 && !text.contains(".") && !text.contains("/")
    }

    // MARK: Redaction

    /// Paints over hidden boxes. Returns a new image (same size).
    static func redact(_ image: CGImage, boxes: [ShieldTextBox], result: ShieldResult) -> CGImage {
        guard result.count > 0 else { return image }
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(CGColor(red: 0.12, green: 0.1, blue: 0.2, alpha: 1))
        for index in result.hidden.keys where index < boxes.count {
            let b = boxes[index]
            let pad = 0.004
            // CoreGraphics is bottom-left origin.
            let rect = CGRect(x: (b.x - pad) * Double(w),
                              y: (1 - b.y - b.height - pad) * Double(h),
                              width: (b.width + pad * 2) * Double(w),
                              height: (b.height + pad * 2) * Double(h))
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 4, cornerHeight: 4, transform: nil))
            ctx.fillPath()
        }
        return ctx.makeImage() ?? image
    }

    static func jpeg(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}

// MARK: - One-call protection for raw frames (Live Guide broadcast)

nonisolated extension PrivacyShield {
    /// OCRs a JPEG, blacks out secrets, and returns the safe JPEG plus what was hidden.
    static func protect(jpeg: Data, quality: Double = 0.6) -> (data: Data, hidden: [SensitiveKind]) {
        guard isEnabled,
              let source = CGImageSourceCreateWithData(jpeg as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return (jpeg, []) }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        guard (try? handler.perform([request])) != nil else { return (jpeg, []) }

        let boxes: [ShieldTextBox] = (request.results ?? []).compactMap { obs in
            guard let text = obs.topCandidates(1).first?.string else { return nil }
            let b = obs.boundingBox
            return ShieldTextBox(text: text, x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height)
        }
        let result = scan(boxes)
        guard result.count > 0 else { return (jpeg, []) }
        let redacted = redact(image, boxes: boxes, result: result)
        return (Self.jpeg(redacted, quality: quality) ?? jpeg, result.kinds)
    }
}

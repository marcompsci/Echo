import Foundation
import UIKit
import Vision

// MARK: - Prepares a screenshot for the guide backend
//
// 1. Downscales the image (faster upload, lower AI cost, same accuracy).
// 2. Runs on-device OCR to find every piece of text and its exact position.
//    The backend lets Claude point at these element IDs, so numbered markers
//    land exactly on the right button.
//
// Runs off the main thread — everything here is nonisolated.

nonisolated struct ScreenTextElement: Codable, Sendable, Hashable {
    let id: String
    let text: String
    let x: Double       // 0–1, top-left origin
    let y: Double
    let width: Double
    let height: Double
}

nonisolated struct PreparedGuideImage: Sendable {
    let jpegData: Data
    let pixelWidth: Int
    let pixelHeight: Int
    let elements: [ScreenTextElement]
    /// What Privacy Shield hid before anything left the phone.
    var hidden: [SensitiveKind] = []
}

nonisolated enum GuideImageError: Error {
    case unreadableImage
}

nonisolated enum ScreenTextReader {

    /// Longest edge sent to the model. Claude downsizes anything larger anyway.
    static let maxLongEdge: CGFloat = 1568

    static func prepare(_ imageData: Data, maxElements: Int = 150) throws -> PreparedGuideImage {
        guard let original = UIImage(data: imageData) else { throw GuideImageError.unreadableImage }

        // Redraw upright and downscaled (also fixes EXIF orientation).
        let size = original.size
        let longEdge = max(size.width, size.height)
        guard longEdge > 0 else { throw GuideImageError.unreadableImage }
        let scale = min(1, maxLongEdge / longEdge)
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            original.draw(in: CGRect(origin: .zero, size: target))
        }

        guard let cgImage = resized.cgImage else { throw GuideImageError.unreadableImage }

        var elements = (try? recognizeText(in: cgImage, limit: maxElements)) ?? []
        var finalImage = cgImage
        var hidden: [SensitiveKind] = []

        // Privacy Shield: black out card numbers, SSNs, passwords, keys — on-device, before upload.
        if PrivacyShield.isEnabled, !elements.isEmpty {
            let boxes = elements.map { ShieldTextBox(text: $0.text, x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
            let result = PrivacyShield.scan(boxes)
            if result.count > 0 {
                finalImage = PrivacyShield.redact(cgImage, boxes: boxes, result: result)
                for (index, kind) in result.hidden {
                    let e = elements[index]
                    elements[index] = ScreenTextElement(id: e.id, text: kind.placeholder, x: e.x, y: e.y, width: e.width, height: e.height)
                }
                hidden = result.kinds
            }
        }

        guard let jpeg = PrivacyShield.jpeg(finalImage, quality: 0.8) ?? resized.jpegData(compressionQuality: 0.8)
        else { throw GuideImageError.unreadableImage }

        return PreparedGuideImage(
            jpegData: jpeg,
            pixelWidth: Int(target.width),
            pixelHeight: Int(target.height),
            elements: elements,
            hidden: hidden
        )
    }

    /// On-device OCR. Returns text lines with boxes in top-left-origin normalized coordinates.
    static func recognizeText(in cgImage: CGImage, limit: Int) throws -> [ScreenTextElement] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        try handler.perform([request])

        let observations = request.results ?? []
        var elements: [ScreenTextElement] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            // Vision uses a bottom-left origin; the app uses top-left.
            let box = observation.boundingBox
            elements.append(ScreenTextElement(
                id: "e\(elements.count + 1)",
                text: String(text.prefix(120)),
                x: box.minX,
                y: 1 - box.maxY,
                width: box.width,
                height: box.height
            ))
            if elements.count >= limit { break }
        }

        // Reading order: top to bottom, then left to right.
        return elements.sorted { a, b in
            abs(a.y - b.y) > 0.01 ? a.y < b.y : a.x < b.x
        }
    }
}

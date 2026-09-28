import Testing
import Foundation
import CoreGraphics
@testable import Echo

// MARK: - Annotation coordinate conversion

@Suite("Annotation Coordinate Conversion")
struct AnnotationRendererTests {

    @Test("absoluteRect scales normalized coordinates to container")
    func absoluteRectScaling() {
        let ann = Annotation(
            type: .roundedRectangle,
            normalizedX: 0.25,
            normalizedY: 0.10,
            normalizedWidth: 0.50,
            normalizedHeight: 0.08,
            label: "1"
        )

        let container = CGSize(width: 400, height: 800)
        let rect = ann.absoluteRect(in: container)

        #expect(rect.origin.x == 100)   // 0.25 * 400
        #expect(rect.origin.y == 80)    // 0.10 * 800
        #expect(rect.width == 200)      // 0.50 * 400
        #expect(rect.height == 64)      // 0.08 * 800
    }

    @Test("absoluteRect handles zero-size container gracefully")
    func absoluteRectZeroContainer() {
        let ann = Annotation(
            type: .circle,
            normalizedX: 0.5,
            normalizedY: 0.5,
            normalizedWidth: 0.1,
            normalizedHeight: 0.1,
            label: ""
        )

        let rect = ann.absoluteRect(in: .zero)

        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 0)
        #expect(rect.width == 0)
        #expect(rect.height == 0)
    }

    @Test("absoluteRect with full-screen normalized values fills container")
    func absoluteRectFullscreen() {
        let ann = Annotation(
            type: .roundedRectangle,
            normalizedX: 0,
            normalizedY: 0,
            normalizedWidth: 1,
            normalizedHeight: 1,
            label: ""
        )

        let container = CGSize(width: 390, height: 844)
        let rect = ann.absoluteRect(in: container)

        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 0)
        #expect(rect.width == 390)
        #expect(rect.height == 844)
    }

    @Test("Annotation color style enum cases are Codable")
    func colorStyleCodable() throws {
        for style in [Annotation.ColorStyle.accent, .warning, .success] {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(Annotation.ColorStyle.self, from: data)
            #expect(decoded == style)
        }
    }

    @Test("Annotation type enum cases are Codable")
    func annotationTypeCodable() throws {
        for type_ in [Annotation.AnnotationType.circle, .roundedRectangle, .arrow, .label] {
            let data = try JSONEncoder().encode(type_)
            let decoded = try JSONDecoder().decode(Annotation.AnnotationType.self, from: data)
            #expect(decoded == type_)
        }
    }
}

// MARK: - EchoSession retention policy

@Suite("EchoSession Retention Policy")
struct SessionRetentionTests {

    @Test("Default retention policy is noSave")
    func defaultRetentionPolicy() {
        let session = EchoSession(question: "q", summary: "s")
        #expect(session.retentionPolicy == .noSave)
        #expect(session.imageData == nil)
    }

    @Test("Retention policy round-trips through rawValue")
    func retentionPolicyRawValue() {
        for policy in EchoSession.ImageRetentionPolicy.allCases {
            let session = EchoSession(
                question: "q",
                summary: "s",
                imageRetentionPolicy: policy
            )
            #expect(session.retentionPolicy == policy)
            #expect(session.imageRetentionPolicy == policy.rawValue)
        }
    }

    @Test("questionPreview truncates at 60 characters")
    func questionPreviewTruncation() {
        let longQ = String(repeating: "a", count: 80)
        let session = EchoSession(question: longQ, summary: "s")
        #expect(session.questionPreview.count <= 63) // 60 + "…"
        #expect(session.questionPreview.hasSuffix("…"))
    }

    @Test("questionPreview does not truncate short questions")
    func questionPreviewShort() {
        let shortQ = "What do I tap next?"
        let session = EchoSession(question: shortQ, summary: "s")
        #expect(session.questionPreview == shortQ)
    }
}

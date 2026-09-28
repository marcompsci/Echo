import Foundation
import CoreGraphics

struct Annotation: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let type: AnnotationType
    let normalizedX: Double      // 0–1, relative to image width
    let normalizedY: Double      // 0–1, relative to image height
    let normalizedWidth: Double  // 0–1, relative to image width
    let normalizedHeight: Double // 0–1, relative to image height
    let label: String
    let colorStyle: ColorStyle

    enum AnnotationType: String, Codable, Sendable, Hashable {
        case circle
        case roundedRectangle
        case arrow
        case label
    }

    enum ColorStyle: String, Codable, Sendable, Hashable {
        case accent
        case warning
        case success
    }

    init(
        id: UUID = UUID(),
        type: AnnotationType,
        normalizedX: Double,
        normalizedY: Double,
        normalizedWidth: Double,
        normalizedHeight: Double,
        label: String,
        colorStyle: ColorStyle = .accent
    ) {
        self.id = id
        self.type = type
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.normalizedWidth = normalizedWidth
        self.normalizedHeight = normalizedHeight
        self.label = label
        self.colorStyle = colorStyle
    }

    // Convert normalized coords to absolute rect within a given container size
    func absoluteRect(in containerSize: CGSize) -> CGRect {
        CGRect(
            x: normalizedX * containerSize.width,
            y: normalizedY * containerSize.height,
            width: normalizedWidth * containerSize.width,
            height: normalizedHeight * containerSize.height
        )
    }
}

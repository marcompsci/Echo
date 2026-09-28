import SwiftUI

struct AnnotationOverlayView: View {
    let image: UIImage
    let annotations: [Annotation]
    let selectedAnnotationID: UUID?
    let onAnnotationTap: (Annotation) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let imageSize = fittedSize(for: image.size, in: geo.size)
            let imageOrigin = CGPoint(
                x: (geo.size.width - imageSize.width) / 2,
                y: (geo.size.height - imageSize.height) / 2
            )

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)

                // Annotation overlays — positioned relative to image
                ForEach(annotations) { ann in
                    let rect = ann.absoluteRect(in: imageSize)
                    let isSelected = ann.id == selectedAnnotationID
                    let color = Color.echoAnnotation(ann.colorStyle)

                    annotationShape(ann, rect: rect, color: color, isSelected: isSelected)
                        .offset(x: imageOrigin.x, y: imageOrigin.y)
                        .onTapGesture { onAnnotationTap(ann) }
                        .animation(reduceMotion ? .none : .spring(duration: 0.25), value: isSelected)
                        .accessibilityLabel(annotationAccessibilityLabel(ann))
                        .accessibilityAddTraits(.isButton)
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                SimultaneousGesture(
                    MagnifyGesture()
                        .onChanged { v in
                            scale = max(1, min(5, lastScale * v.magnification))
                        }
                        .onEnded { _ in lastScale = scale },
                    DragGesture()
                        .onChanged { v in
                            offset = CGSize(
                                width: lastOffset.width + v.translation.width,
                                height: lastOffset.height + v.translation.height
                            )
                        }
                        .onEnded { _ in lastOffset = offset }
                )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.4)) {
                    scale = 1
                    offset = .zero
                    lastScale = 1
                    lastOffset = .zero
                }
            }
        }
        .clipped()
    }

    // MARK: - Shape builder

    @ViewBuilder
    private func annotationShape(_ ann: Annotation, rect: CGRect, color: Color, isSelected: Bool) -> some View {
        let strokeWidth: CGFloat = isSelected ? 3 : 2
        let opacity: Double = isSelected ? 1 : 0.85

        switch ann.type {
        case .roundedRectangle:
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(color, lineWidth: strokeWidth)
                    .frame(width: rect.width, height: rect.height)
                    .shadow(color: color.opacity(0.4), radius: isSelected ? 8 : 4)
                    .opacity(opacity)

                if !ann.label.isEmpty {
                    numberBadge(ann.label, color: color, isSelected: isSelected)
                        .offset(x: -10, y: -12)
                }
            }
            .position(x: rect.midX, y: rect.midY)

        case .circle:
            ZStack {
                Circle()
                    .strokeBorder(color, lineWidth: strokeWidth)
                    .frame(width: rect.width, height: rect.height)
                    .shadow(color: color.opacity(0.4), radius: isSelected ? 8 : 4)
                    .opacity(opacity)
                if !ann.label.isEmpty {
                    numberBadge(ann.label, color: color, isSelected: isSelected)
                        .offset(x: rect.width / 2 - 8, y: -rect.height / 2 + 4)
                }
            }
            .position(x: rect.midX, y: rect.midY)

        case .arrow:
            ArrowShape()
                .fill(color)
                .frame(width: rect.width, height: rect.height)
                .opacity(opacity)
                .shadow(color: color.opacity(0.4), radius: isSelected ? 8 : 3)
                .position(x: rect.midX, y: rect.midY)

        case .label:
            Text(ann.label)
                .font(.echoCaption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .opacity(opacity)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    private func numberBadge(_ label: String, color: Color, isSelected: Bool) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(color)
            .clipShape(Circle())
            .shadow(color: color.opacity(0.5), radius: isSelected ? 6 : 2)
            .scaleEffect(isSelected ? 1.15 : 1.0)
    }

    private func annotationAccessibilityLabel(_ ann: Annotation) -> String {
        var parts: [String] = []
        if !ann.label.isEmpty { parts.append("Step \(ann.label)") }
        parts.append(ann.type.rawValue.replacingOccurrences(of: "roundedRectangle", with: "highlighted area"))
        return parts.joined(separator: ", ")
    }

    // MARK: - Helpers

    private func fittedSize(for imageSize: CGSize, in containerSize: CGSize) -> CGSize {
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let ratio = min(widthRatio, heightRatio)
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }
}

// MARK: - Arrow Shape

private struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let headRatio: CGFloat = 0.45
        let stemWidth: CGFloat = w * 0.25

        // Stem
        path.move(to: CGPoint(x: w / 2 - stemWidth / 2, y: h))
        path.addLine(to: CGPoint(x: w / 2 + stemWidth / 2, y: h))
        path.addLine(to: CGPoint(x: w / 2 + stemWidth / 2, y: h * headRatio))
        // Arrow head
        path.addLine(to: CGPoint(x: w, y: h * headRatio))
        path.addLine(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: h * headRatio))
        path.addLine(to: CGPoint(x: w / 2 - stemWidth / 2, y: h * headRatio))
        path.closeSubpath()
        return path
    }
}

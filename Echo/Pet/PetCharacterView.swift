import SwiftUI

// MARK: - Rendered pet character — pure SwiftUI shapes, no assets required

struct PetCharacterView: View {
    let mood: PetMood
    let bodyColor: PetBodyColor
    let accessory: PetAccessory
    let isBlinking: Bool
    let pupilOffset: CGSize
    let isExcited: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            // Drop shadow
            Ellipse()
                .fill(bodyColor.shadowColor)
                .frame(width: size * 0.58, height: size * 0.09)
                .blur(radius: 4)
                .offset(y: size * 0.43)

            // Halo behind body
            if accessory == .halo { haloView.offset(y: -size * 0.41) }

            // Ear bumps (drawn before body so body overlaps the base)
            HStack(spacing: size * 0.40) { earView; earView }
                .offset(y: -size * 0.28)

            // Body
            RoundedRectangle(cornerRadius: size * 0.30)
                .fill(LinearGradient(
                    colors: [bodyColor.color.opacity(0.88), bodyColor.color],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: size * 0.80, height: size * 0.66)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.30)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1.5)
                )
                .offset(y: size * 0.04)
                .overlay(faceView.offset(y: size * 0.04))

            // Front accessories
            if accessory != .halo && accessory != .none {
                frontAccessoryView.offset(y: -size * 0.44)
            }

            // Cheek blush
            if mood == .happy || mood == .excited {
                HStack(spacing: size * 0.40) {
                    cheek; cheek
                }
                .offset(y: size * 0.10)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isExcited ? 1.10 : 1.0)
        .animation(.spring(duration: 0.25, bounce: 0.6), value: isExcited)
    }

    // MARK: - Ear

    private var earView: some View {
        Circle()
            .fill(bodyColor.color)
            .frame(width: size * 0.19, height: size * 0.19)
            .overlay(
                Circle()
                    .fill(bodyColor.color.opacity(0.55))
                    .frame(width: size * 0.09, height: size * 0.09)
            )
    }

    // MARK: - Cheek

    private var cheek: some View {
        Ellipse()
            .fill(Color(red: 1.0, green: 0.60, blue: 0.65).opacity(0.55))
            .frame(width: size * 0.14, height: size * 0.08)
    }

    // MARK: - Face overlay

    private var faceView: some View {
        VStack(spacing: size * 0.08) {
            HStack(spacing: size * 0.17) {
                PetEyeView(size: size * 0.17, isBlinking: isBlinking, squint: mood.eyeSquint, pupilOffset: pupilOffset)
                PetEyeView(size: size * 0.17, isBlinking: isBlinking, squint: mood.eyeSquint, pupilOffset: pupilOffset)
            }
            PetMouthView(size: size, smileAmount: mood.smileAmount)
        }
        .offset(y: -size * 0.02)
    }

    // MARK: - Halo accessory

    private var haloView: some View {
        Ellipse()
            .strokeBorder(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.92, blue: 0.30), Color.white.opacity(0.70)],
                    startPoint: .leading, endPoint: .trailing
                ),
                lineWidth: 3
            )
            .frame(width: size * 0.50, height: size * 0.10)
            .rotationEffect(.degrees(-10))
    }

    // MARK: - Front accessories

    @ViewBuilder
    private var frontAccessoryView: some View {
        switch accessory {
        case .antenna:
            VStack(spacing: 0) {
                Circle()
                    .fill(bodyColor.color)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                    .frame(width: size * 0.13, height: size * 0.13)
                Rectangle()
                    .fill(bodyColor.color.opacity(0.80))
                    .frame(width: 2.5, height: size * 0.15)
            }
        case .bow:
            HStack(spacing: 1) {
                TriangleShape()
                    .fill(Color(red: 0.957, green: 0.443, blue: 0.706))
                    .frame(width: size * 0.13, height: size * 0.11)
                    .scaleEffect(x: -1)
                Circle()
                    .fill(Color(red: 1.0, green: 0.75, blue: 0.88))
                    .frame(width: size * 0.07, height: size * 0.07)
                TriangleShape()
                    .fill(Color(red: 0.957, green: 0.443, blue: 0.706))
                    .frame(width: size * 0.13, height: size * 0.11)
            }
        case .hat:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.10, green: 0.08, blue: 0.22))
                    .frame(width: size * 0.34, height: size * 0.19)
                Capsule()
                    .fill(Color(red: 0.15, green: 0.12, blue: 0.30))
                    .frame(width: size * 0.50, height: size * 0.07)
            }
        case .halo, .none:
            EmptyView()
        }
    }
}

// MARK: - Eye

private struct PetEyeView: View {
    let size: CGFloat
    let isBlinking: Bool
    let squint: Double
    let pupilOffset: CGSize

    private var eyeOpenHeight: CGFloat { size * CGFloat(max(0.35, 1.0 - squint * 0.65)) }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.white)
                .frame(width: size, height: isBlinking ? size * 0.06 : eyeOpenHeight)
                .animation(.easeInOut(duration: 0.07), value: isBlinking)
                .animation(.easeInOut(duration: 0.15), value: squint)

            if !isBlinking {
                Circle()
                    .fill(Color(red: 0.12, green: 0.05, blue: 0.22))
                    .frame(width: size * 0.52, height: size * 0.52)
                    .offset(x: pupilOffset.width, y: pupilOffset.height)

                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: size * 0.20, height: size * 0.20)
                    .offset(
                        x: pupilOffset.width - size * 0.14,
                        y: pupilOffset.height - size * 0.14
                    )
            }
        }
        .clipShape(Ellipse())
        .frame(width: size, height: size)
    }
}

// MARK: - Mouth

private struct PetMouthView: View {
    let size: CGFloat
    let smileAmount: Double

    var body: some View {
        Canvas { ctx, sz in
            var path = Path()
            let mx = sz.width / 2
            let my = sz.height / 2
            let hw = sz.width * 0.5
            path.move(to: CGPoint(x: mx - hw, y: my))
            path.addQuadCurve(
                to:      CGPoint(x: mx + hw, y: my),
                control: CGPoint(x: mx,      y: my - CGFloat(smileAmount) * sz.height * 0.75)
            )
            ctx.stroke(
                path,
                with: .color(Color(red: 0.12, green: 0.05, blue: 0.22).opacity(0.70)),
                style: StrokeStyle(lineWidth: max(1.5, size * 0.05), lineCap: .round)
            )
        }
        .frame(width: size * 0.32, height: size * 0.16)
    }
}

// MARK: - Triangle shape for bow

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to:    CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        ForEach([PetMood.happy, .sleepy, .excited, .hungry], id: \.rawValue) { mood in
            PetCharacterView(
                mood: mood,
                bodyColor: .lavender,
                accessory: .antenna,
                isBlinking: false,
                pupilOffset: .zero,
                isExcited: mood == .excited,
                size: 80
            )
        }
    }
    .padding()
    .background(Color(red: 0.05, green: 0.07, blue: 0.14))
}

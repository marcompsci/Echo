import SwiftUI

// MARK: - Reusable card container

struct EchoCard<Content: View>: View {
    let elevated: Bool
    @ViewBuilder let content: Content

    init(elevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.elevated = elevated
        self.content = content()
    }

    var body: some View {
        content
            .background(elevated ? Color.echoSurfaceElevated : Color.echoSurface)
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
            .shadow(
                color: Color.black.opacity(EchoSpacing.Shadow.softOpacity),
                radius: EchoSpacing.Shadow.softRadius,
                y: EchoSpacing.Shadow.softY
            )
    }
}

// MARK: - Echo Orb — animated glowing sphere

struct EchoOrb: View {
    var size: CGFloat = 120
    @State private var pulsing = false
    @State private var rotating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Outer ambient glow
            Circle()
                .fill(RadialGradient.echoOrbGlow(radius: size * 0.75))
                .frame(width: size * 1.6, height: size * 1.6)
                .scaleEffect(pulsing ? 1.12 : 1.0)
                .opacity(0.7)

            // Middle ring
            Circle()
                .strokeBorder(LinearGradient.echoAccent, lineWidth: 1.5)
                .frame(width: size * 1.15, height: size * 1.15)
                .scaleEffect(pulsing ? 1.06 : 0.96)
                .opacity(0.5)

            // Core orb
            Circle()
                .fill(LinearGradient.echoAccent)
                .frame(width: size, height: size)
                .overlay {
                    // "E" mark — guiding light letterform
                    Text("E")
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .white.opacity(0.4), radius: 6, y: 0)
                }

            // Specular highlight
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.3
                    )
                )
                .frame(width: size * 0.55, height: size * 0.35)
                .offset(x: -size * 0.1, y: -size * 0.18)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color.echoBackground.ignoresSafeArea()
        VStack(spacing: 32) {
            EchoOrb(size: 120)
            EchoOrb(size: 64)
        }
    }
}

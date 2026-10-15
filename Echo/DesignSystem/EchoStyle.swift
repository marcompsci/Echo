import SwiftUI

// MARK: - Echo visual system (calm & premium)
//
// • Ambient background: slow, soft lavender/mint light behind every screen
// • Glass surfaces: iOS 26 Liquid Glass, with a quiet material fallback
// • Motion: one gentle spring everywhere, respects Reduce Motion
// • Haptics: light taps for selections, soft success when Echo finishes

enum EchoMotion {
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.86)
    static let quick  = Animation.spring(response: 0.3, dampingFraction: 0.9)
    static let slow   = Animation.easeInOut(duration: 9).repeatForever(autoreverses: true)
}

extension Font {
    /// Big, calm display type for greetings and hero titles.
    static let echoDisplay = Font.system(size: 34, weight: .bold, design: .rounded)
    static let echoEyebrow = Font.system(.caption, design: .rounded, weight: .semibold)
}

// MARK: Ambient background

struct EchoAmbientBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            Color.echoBackground
            Circle()
                .fill(Color.echoLavender.opacity(scheme == .dark ? 0.35 : 0.22))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: drift ? -120 : -60, y: drift ? -300 : -240)
            Circle()
                .fill(Color.echoMint.opacity(scheme == .dark ? 0.18 : 0.16))
                .frame(width: 360, height: 360)
                .blur(radius: 130)
                .offset(x: drift ? 150 : 90, y: drift ? 60 : 140)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(EchoMotion.slow) { drift = true }
        }
    }
}

// MARK: Glass surface

struct EchoGlass: ViewModifier {
    var cornerRadius: CGFloat = EchoSpacing.Corner.xl
    var tint: Color? = nil
    var interactive = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? .regular.tint(tint).interactive() : .regular.tint(tint), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.08)))
        }
    }
}

extension View {
    func echoGlass(cornerRadius: CGFloat = EchoSpacing.Corner.xl, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(EchoGlass(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    /// Ambient background for any screen.
    func echoScreenBackground() -> some View {
        background(EchoAmbientBackground())
    }
}

// MARK: Pressable button style (soft scale + haptic)

struct EchoPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(EchoMotion.quick, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

extension ButtonStyle where Self == EchoPressStyle {
    static var echoPress: EchoPressStyle { EchoPressStyle() }
}

// MARK: Section header

struct EchoSectionHeader: View {
    let title: String
    var action: (title: String, run: () -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.echoTitle3)
                .foregroundStyle(.echoTextPrimary)
            Spacer()
            if let action {
                Button(action.title, action: action.run)
                    .font(.echoFootnote.weight(.semibold))
                    .foregroundStyle(.echoLavender)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

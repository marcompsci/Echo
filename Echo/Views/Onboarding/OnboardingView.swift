import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color.echoBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    OnboardingPage1().tag(0)
                    OnboardingPage2().tag(1)
                    OnboardingPage3(onComplete: onComplete).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.35), value: page)

                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Capsule()
                            .fill(
                                i == page
                                    ? AnyShapeStyle(LinearGradient.echoAccent)
                                    : AnyShapeStyle(Color.echoTextTertiary)
                            )
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(duration: 0.35), value: page)
                    }
                }
                .padding(.bottom, EchoSpacing.xxl)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(page + 1) of 3")
            }
        }
    }
}

// MARK: - Page 1: Meet Echo

private struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: EchoSpacing.xl) {
            Spacer()

            EchoOrb(size: 140)

            VStack(spacing: EchoSpacing.sm) {
                Text("Meet Echo")
                    .font(.echoLargeTitle)
                    .foregroundStyle(.echoTextPrimary)
                    .multilineTextAlignment(.center)

                Text("A clearer way to understand\nwhat's on your screen.")
                    .font(.echoCallout)
                    .foregroundStyle(.echoTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, EchoSpacing.xl)
    }
}

// MARK: - Page 2: Privacy

private struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: EchoSpacing.xl) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 72))
                .foregroundStyle(LinearGradient.echoAccent)
                .accessibilityHidden(true)

            VStack(spacing: EchoSpacing.sm) {
                Text("You choose what\nEcho sees")
                    .font(.echoTitle)
                    .foregroundStyle(.echoTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Echo only analyzes screenshots, photos,\nand questions you deliberately share.")
                    .font(.echoCallout)
                    .foregroundStyle(.echoTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            PrivacyPromiseCard()

            Spacer()
        }
        .padding(.horizontal, EchoSpacing.lg)
    }
}

// MARK: - Page 3: Ask. See. Do.

private struct OnboardingPage3: View {
    var onComplete: () -> Void
    @State private var iconScale = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let steps: [(icon: String, label: String)] = [
        ("photo.badge.plus", "Share a screenshot"),
        ("text.bubble", "Ask a question"),
        ("sparkles", "Get a visual next step")
    ]

    var body: some View {
        VStack(spacing: EchoSpacing.xl) {
            Spacer()

            VStack(spacing: EchoSpacing.sm) {
                Text("Ask. See. Do.")
                    .font(.echoLargeTitle)
                    .foregroundStyle(.echoTextPrimary)
                    .multilineTextAlignment(.center)

                Text("Share a screen, ask a question,\nand get a visual next step.")
                    .font(.echoCallout)
                    .foregroundStyle(.echoTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            HStack(spacing: EchoSpacing.lg) {
                ForEach(steps, id: \.label) { step in
                    VStack(spacing: EchoSpacing.xs) {
                        Image(systemName: step.icon)
                            .font(.system(size: 32))
                            .foregroundStyle(LinearGradient.echoAccent)
                            .accessibilityHidden(true)
                        Text(step.label)
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(EchoSpacing.lg)
            .background(Color.echoSurface)
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))

            Spacer()

            EchoButton("Continue to Echo") {
                onComplete()
            }
            .accessibilityHint("Opens the main Echo screen")

            Spacer().frame(height: EchoSpacing.lg)
        }
        .padding(.horizontal, EchoSpacing.lg)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}

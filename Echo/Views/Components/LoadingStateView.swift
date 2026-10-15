import SwiftUI

// MARK: - Calm "Echo is thinking" state
//
// The real orb swirls in its thinking mode while a short line of status text
// gently cycles, so waiting feels alive instead of stuck.

struct LoadingStateView: View {
    var message: String = "Echo is working on it…"
    var hints: [String] = ["Reading what's on screen…", "Finding the clearest next step…", "Almost there…"]

    @State private var hintIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: EchoSpacing.lg) {
            EchoOrbView(size: 120)
                .accessibilityHidden(true)

            VStack(spacing: EchoSpacing.xs) {
                Text(message)
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextPrimary)
                    .multilineTextAlignment(.center)

                Text(hints.isEmpty ? "" : hints[hintIndex % hints.count])
                    .font(.echoFootnote)
                    .foregroundStyle(.echoTextSecondary)
                    .contentTransition(.opacity)
                    .id(hintIndex)
                    .transition(.opacity)
            }
        }
        .padding(EchoSpacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .onAppear { EchoVoiceActivity.shared.setMode(.thinking) }
        .onDisappear { EchoVoiceActivity.shared.setMode(.idle) }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { hintIndex += 1 }
            }
        }
    }
}

#Preview {
    ZStack {
        EchoAmbientBackground()
        LoadingStateView()
    }
}

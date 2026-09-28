import SwiftUI

struct LoadingStateView: View {
    var message: String = "Echo is working on it…"
    @State private var dotCount = 0

    var body: some View {
        VStack(spacing: EchoSpacing.lg) {
            EchoOrb(size: 80)

            VStack(spacing: EchoSpacing.xs) {
                Text(message)
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(
                                i < dotCount
                                    ? AnyShapeStyle(LinearGradient.echoAccent)
                                    : AnyShapeStyle(Color.echoTextTertiary)
                            )
                            .frame(width: 7, height: 7)
                            .animation(.easeInOut(duration: 0.3).delay(Double(i) * 0.12), value: dotCount)
                    }
                }
            }
        }
        .padding(EchoSpacing.xl)
        .onAppear { startPulsing() }
    }

    private func startPulsing() {
        Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { timer in
            dotCount = (dotCount + 1) % 4
            if dotCount == 0 {
                // brief pause before restart
            }
        }
    }
}

#Preview {
    ZStack {
        Color.echoBackground.ignoresSafeArea()
        LoadingStateView(message: "Echo is looking for the clearest next step…")
    }
}

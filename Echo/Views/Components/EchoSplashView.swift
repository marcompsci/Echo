import SwiftUI

// MARK: - Splash
//
// Picks up exactly where the iOS launch screen leaves off (same artwork, same
// spot), then the pet does a happy little hop and the app fades in.

struct EchoSplashView: View {
    var onFinished: () -> Void
    @State private var hop = false
    @State private var leaving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchMark")
                .offset(y: hop ? -14 : 0)
                .scaleEffect(leaving ? 1.08 : 1)
                .accessibilityLabel("Echo")
        }
        .opacity(leaving ? 0 : 1)
        .task {
            if reduceMotion {
                try? await Task.sleep(for: .milliseconds(350))
            } else {
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { hop = true }
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { hop = false }
                try? await Task.sleep(for: .milliseconds(380))
            }
            withAnimation(.easeOut(duration: 0.35)) { leaving = true }
            try? await Task.sleep(for: .milliseconds(360))
            onFinished()
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: hop) { _, new in new }
    }
}

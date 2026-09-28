import SwiftUI

struct VoiceQuestionButton: View {
    let isRecording: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: EchoSpacing.sm) {
            ZStack {
                // Pulse ring — visible while recording
                if isRecording && !reduceMotion {
                    Circle()
                        .strokeBorder(Color.echoLavender.opacity(0.4), lineWidth: 3)
                        .frame(width: 96, height: 96)
                        .scaleEffect(pulseScale)
                        .opacity(isRecording ? 1 : 0)
                }

                // Core button
                Circle()
                    .fill(isRecording
                          ? AnyShapeStyle(Color.echoLavender)
                          : AnyShapeStyle(Color.echoSurface))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isRecording
                                    ? AnyShapeStyle(Color.clear)
                                    : AnyShapeStyle(LinearGradient.echoAccent),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: isRecording
                            ? Color.echoLavender.opacity(0.4)
                            : Color.black.opacity(0.1),
                        radius: isRecording ? 16 : 6,
                        y: 4
                    )
                    .overlay {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(isRecording ? .white : AnyShapeStyle(LinearGradient.echoAccent))
                    }
                    .scaleEffect(isPressed ? 0.92 : 1.0)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            triggerHaptic()
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        triggerHaptic()
                        onRelease()
                    }
            )
            .animation(.spring(duration: 0.25), value: isRecording)
            .animation(.spring(duration: 0.15), value: isPressed)
            .onAppear { startPulseAnimation() }
            .onChange(of: isRecording) { _, recording in
                if recording { startPulseAnimation() }
            }
            .accessibilityLabel(isRecording ? "Stop recording" : "Hold to record your question")
            .accessibilityAddTraits(.isButton)

            Text(isRecording ? "Recording — release to stop" : "Hold to speak")
                .font(.echoCaption)
                .foregroundStyle(isRecording ? .echoLavender : .echoTextTertiary)
                .animation(.easeInOut(duration: 0.2), value: isRecording)
        }
    }

    private func startPulseAnimation() {
        guard !reduceMotion else { return }
        pulseScale = 1.0
        withAnimation(.easeOut(duration: 0.8).repeatForever(autoreverses: false)) {
            pulseScale = 1.5
        }
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

#Preview {
    ZStack {
        Color.echoBackground.ignoresSafeArea()
        VStack(spacing: 32) {
            VoiceQuestionButton(isRecording: false, onPress: {}, onRelease: {})
            VoiceQuestionButton(isRecording: true, onPress: {}, onRelease: {})
        }
    }
}

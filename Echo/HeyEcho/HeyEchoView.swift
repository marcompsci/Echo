import SwiftUI

// MARK: - "Hey Echo" — talk to Echo like Siri
//
// Opens listening. Say anything:
//   • "Remind me to call mom at 6"      → Echo Agent plan → you approve → done
//   • "What do I tap here?"             → your latest screenshot, analyzed
//   • "Walk me through turning on Wi-Fi" → Live Guide with that goal
//   • "What's a good tip for 4 people?" → Echo answers out loud

struct HeyEchoView: View {
    var greeting: String? = nil
    var onRoute: (HeyEchoRoute) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var listener = HeyEchoListener()
    @State private var narrator = GuideNarrator()
    @State private var phase: Phase = .listening
    @State private var heard = ""
    @State private var reply = ""
    @State private var plan: AgentPlan? = nil
    @State private var showPlan = false

    enum Phase { case listening, thinking, replying, done }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.echoLavender.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: EchoSpacing.lg) {
                HStack {
                    Spacer()
                    Button {
                        listener.stop(); narrator.stop(); dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .accessibilityLabel("Close")
                }

                Spacer()

                EchoOrbView(size: 220)
                    .onTapGesture { if phase != .listening { Task { await run() } } }
                    .accessibilityHint("Tap to ask again")

                Text(statusText)
                    .font(.echoHeadline)
                    .foregroundStyle(.white.opacity(0.7))

                Text(phase == .listening ? listener.transcript : (reply.isEmpty ? heard : reply))
                    .font(.echoTitle3)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EchoSpacing.lg)
                    .frame(minHeight: 80)
                    .animation(.easeInOut, value: listener.transcript)

                Spacer()

                if phase == .listening {
                    Button("Done") { listener.stop() }
                        .font(.echoHeadline)
                        .foregroundStyle(.white)
                } else if phase == .done {
                    Button {
                        Task { await run() }
                    } label: {
                        Label("Ask again", systemImage: "mic.fill")
                            .font(.echoHeadline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, EchoSpacing.lg)
                            .padding(.vertical, EchoSpacing.sm)
                            .background(.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(EchoSpacing.lg)
        }
        .task {
            if let greeting { await speakAndWait(greeting) }
            await run()
        }
        .onDisappear { listener.stop(); narrator.stop(); EchoPresence.rest() }
        .sheet(isPresented: $showPlan) {
            if let plan {
                AgentPlanView(
                    plan: plan,
                    onConfirm: { showPlan = false; Task { await execute(plan) } },
                    onCancel: { showPlan = false; say("Okay, I won't do that.") }
                )
            }
        }
    }

    private var statusText: String {
        switch phase {
        case .listening: return "Listening…"
        case .thinking:  return "Thinking…"
        case .replying:  return "Echo"
        case .done:      return reply.isEmpty ? "Tap the orb to ask again" : "Echo"
        }
    }

    // MARK: - Flow

    private func run() async {
        narrator.stop()
        reply = ""
        plan = nil
        phase = .listening
        EchoPresence.update(.listening, "Listening…")
        heard = await listener.listen()

        phase = .thinking
        EchoPresence.update(.thinking, heard.isEmpty ? "Thinking…" : "“\(heard)”")
        EchoVoiceActivity.shared.setMode(.thinking)
        let route = await HeyEchoBrain().route(heard)
        EchoVoiceActivity.shared.setMode(.idle)

        switch route {
        case .nothingHeard:
            phase = .done
            reply = "I didn't catch that. Tap the orb and try again."
        case .answer(let text):
            say(text)
        case .doTask(let request):
            let plan = try? await LiveAgentService().analyze(request: AgentRequest(text: request))
            if let plan, !plan.actions.isEmpty {
                self.plan = plan
                say(plan.explanation + " Want me to go ahead?")
                showPlan = true
            } else {
                say(plan?.explanation ?? "I can't do that one yet.")
            }
        case .helpWithScreen, .walkMeThrough:
            onRoute(route)
            dismiss()
        }
    }

    private func execute(_ plan: AgentPlan) async {
        phase = .thinking
        do {
            let result = try await LiveAgentService().execute(plan: plan)
            if result.isFullySuccessful {
                say("Done.")
            } else {
                say("I couldn't finish that. \(result.failedActions.first?.1 ?? "")")
            }
        } catch {
            say("Something went wrong. \(error.localizedDescription)")
        }
    }

    /// Says something, then returns once Echo has finished talking.
    private func speakAndWait(_ text: String) async {
        reply = text
        phase = .replying
        narrator.speak(text: text)
        try? await Task.sleep(for: .milliseconds(300))
        while narrator.isSpeaking, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func say(_ text: String) {
        reply = text
        phase = .done
        narrator.speak(text: text)
        EchoPresence.update(.speaking, text)
    }
}

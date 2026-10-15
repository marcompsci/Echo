import SwiftUI

// MARK: - "Hey Echo" — talk to Echo like Siri
//
// Opens listening. Say anything:
//   • "Remind me to call mom at 6"      → Echo Agent plan → you approve → done
//   • "What do I tap here?"             → your latest screenshot, analyzed
//   • "Walk me through turning on Wi-Fi" → Live Guide with that goal
//   • "What's a good tip for 4 people?" → Echo answers out loud (follow-ups work)
//   • "Remember my gym is Crunch"       → saved to What Echo Remembers
//   • "Undo that"                        → reverses what Echo just did
//   • Your own Echo Skills               → "good morning" runs your shortcut

struct HeyEchoView: View {
    var greeting: String? = nil
    /// Asked via a link, Shortcut, or Skill — handled without listening first.
    var initialText: String? = nil
    var onRoute: (HeyEchoRoute) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var listener = HeyEchoListener()
    @State private var narrator = GuideNarrator()
    @State private var phase: Phase = .listening
    @State private var heard = ""
    @State private var reply = ""
    @State private var plan: AgentPlan? = nil
    @State private var showPlan = false
    @State private var brain = HeyEchoBrain()
    @State private var canUndo = false
    @AppStorage(EchoVoicePrefs.simpleModeKey) private var simpleMode = false

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
                    .font(simpleMode ? .echoTitle : .echoTitle3)
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
                    HStack(spacing: EchoSpacing.md) {
                        if canUndo {
                            Button {
                                Task { await undo() }
                            } label: {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                                    .font(.echoHeadline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, EchoSpacing.lg)
                                    .padding(.vertical, EchoSpacing.sm)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
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
            }
            .padding(EchoSpacing.lg)
        }
        .task {
            if let greeting, initialText == nil { await speakAndWait(greeting) }
            await run(preset: initialText)
        }
        .onDisappear { listener.stop(); narrator.stop(); brain.resetConversation(); EchoPresence.rest() }
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

    private func run(preset: String? = nil) async {
        narrator.stop()
        reply = ""
        plan = nil
        canUndo = false
        if let preset, !preset.isEmpty {
            heard = preset
        } else {
            phase = .listening
            EchoPresence.update(.listening, "Listening…")
            heard = await listener.listen()
        }

        phase = .thinking
        EchoPresence.update(.thinking, heard.isEmpty ? "Thinking…" : "“\(heard)”")
        EchoVoiceActivity.shared.setMode(.thinking)
        let start = ContinuousClock.now
        let route = await brain.route(heard)
        EchoVoiceActivity.shared.setMode(.idle)
        DevInspector.shared.record(DevTrace(
            feature: "Hey Echo", engine: Self.engineName(for: route), input: heard,
            outcome: Self.describe(route), latencyMs: DevInspector.milliseconds(since: start),
            succeeded: route != .nothingHeard, usedPersonalContext: !EchoPersonalContext.text().isEmpty))

        switch route {
        case .nothingHeard:
            phase = .done
            reply = "I didn't catch that. Tap the orb and try again."
        case .answer(let text):
            await sayThenMaybeListen(text)
        case .doTask(let request):
            await planTask(request, origin: "Hey Echo")
        case .remember(let fact):
            do {
                let saved = try EchoMemory.shared.remember(fact, source: .voice)
                say("Got it. I'll remember: \(saved.text)")
            } catch {
                say(error.localizedDescription)
            }
        case .forget(let what):
            let removed = EchoMemory.shared.forget(matching: what)
            say(removed == 0 ? "I don't have anything saved about that." : "Okay, I forgot that.")
        case .undo:
            await undo()
        case .skill(let skill):
            await runSkill(skill)
        case .helpWithScreen, .walkMeThrough:
            onRoute(route)
            dismiss()
        }
    }

    private func planTask(_ request: String, origin: String) async {
        let plan = try? await LiveAgentService(origin: origin).analyze(request: AgentRequest(text: request))
        guard let plan, !plan.actions.isEmpty else {
            say(plan?.explanation ?? "I can't do that one yet.")
            return
        }
        // Trust setting: small, undoable things can run right away.
        if EchoAutonomy.canRunWithoutAsking(plan) {
            await execute(plan, origin: origin)
            return
        }
        self.plan = plan
        say(plan.explanation + " Want me to go ahead?")
        showPlan = true
    }

    private func runSkill(_ skill: EchoSkill) async {
        switch skill.action {
        case .say(let text):
            await sayThenMaybeListen(text)
        case .runShortcut(let name):
            await open("shortcuts://run-shortcut?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)",
                       saying: "Running \(name).", skill: skill)
        case .openURL(let link):
            await open(link, saying: "Opening it now.", skill: skill)
        case .liveGuide(let goal):
            onRoute(.walkMeThrough(goal))
            dismiss()
        case .agent(let request):
            await planTask(request, origin: "Skill: \(skill.name)")
        }
    }

    private func open(_ link: String, saying text: String, skill: EchoSkill) async {
        guard let url = URL(string: link) else {
            say("That skill's link doesn't look right. Check it in Echo Skills.")
            return
        }
        ActivityLog.shared.record(ActivityEntry(batch: UUID(), summary: "\(skill.name): \(skill.action.kindTitle)",
                                                icon: skill.action.icon, origin: "Skill", status: .handedOff))
        say(text)
        try? await Task.sleep(for: .milliseconds(700))
        let ok = await UIApplication.shared.open(url)
        if !ok { say("I couldn't open that. Is the app or shortcut installed?") }
    }

    private func execute(_ plan: AgentPlan, origin: String = "Hey Echo") async {
        phase = .thinking
        do {
            let result = try await LiveAgentService(origin: origin).execute(plan: plan)
            canUndo = ActivityLog.shared.lastUndoableBatch != nil
                && result.completedActions.contains(where: \.isLowRisk)
            if result.isFullySuccessful {
                say(canUndo ? "Done. Say “undo that” if it's not right." : "Done.")
            } else {
                say("I couldn't finish that. \(result.failedActions.first?.1 ?? "")")
            }
        } catch {
            say("Something went wrong. \(error.localizedDescription)")
        }
    }

    private func undo() async {
        phase = .thinking
        let sentence = await ActivityLog.shared.undoLast()
        canUndo = false
        say(sentence)
    }

    /// Conversation mode: after answering, keep listening for a follow-up.
    private func sayThenMaybeListen(_ text: String) async {
        guard EchoVoicePrefs.keepListening else { say(text); return }
        await speakAndWait(text)
        EchoPresence.update(.speaking, text)
        await run()
    }

    private static func engineName(for route: HeyEchoRoute) -> String {
        switch route {
        case .remember, .forget, .undo: return "On-device command"
        case .skill: return "Echo Skill"
        default: return AppleIntelligence.isAvailable ? "Apple Intelligence" : "Keywords"
        }
    }

    private static func describe(_ route: HeyEchoRoute) -> String {
        switch route {
        case .doTask: return "Task → Echo Agent"
        case .helpWithScreen: return "Screen help"
        case .walkMeThrough(let goal): return "Live Guide: \(goal)"
        case .answer(let a): return "Answer: \(a.prefix(80))"
        case .remember: return "Saved to memory"
        case .forget: return "Forgot from memory"
        case .undo: return "Undo"
        case .skill(let s): return "Skill: \(s.name)"
        case .nothingHeard: return "Nothing heard"
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

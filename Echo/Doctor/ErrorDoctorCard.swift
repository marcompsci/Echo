import SwiftUI

// MARK: - "Echo spotted an error" card (top of the result screen)

struct ErrorDoctorCard: View {
    let imageData: Data?
    /// Called right before Echo speaks, so the guide narration can stop.
    var willSpeak: () -> Void = {}

    @State private var diagnosis: ErrorDiagnosis? = nil
    @State private var errorLines: [String] = []
    @State private var thinking = false
    @State private var aiNote: String? = nil
    @State private var showPermission = false
    @State private var doneMessage: String? = nil
    @State private var narrator = GuideNarrator()
    @AppStorage(GuideNarrator.autoSpeakKey) private var speakAloud = true

    var body: some View {
        Group {
            if let diagnosis {
                VStack(alignment: .leading, spacing: EchoSpacing.sm) {
                    HStack(spacing: 8) {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(.echoLavender)
                        Text("Echo spotted an error")
                            .font(.echoFootnote.weight(.semibold))
                            .foregroundStyle(.echoLavender)
                        Spacer()
                        if thinking { ProgressView().controlSize(.small) }
                    }
                    if !diagnosis.errorText.isEmpty {
                        Text("“\(diagnosis.errorText)”")
                            .font(.echoFootnote)
                            .italic()
                            .foregroundStyle(.echoTextSecondary)
                    }
                    Text(diagnosis.title)
                        .font(.echoHeadline)
                        .foregroundStyle(.echoTextPrimary)
                    Text("Why: \(diagnosis.cause)")
                        .font(.echoSubheadline)
                        .foregroundStyle(.echoTextPrimary)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(diagnosis.steps.enumerated()), id: \.offset) { i, step in
                            Text("\(i + 1). \(step)")
                                .font(.echoSubheadline)
                                .foregroundStyle(.echoTextSecondary)
                        }
                    }
                    Text("Answer from \(diagnosis.source)\(aiNote.map { " · \($0)" } ?? "")")
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextTertiary)

                    if let doneMessage {
                        Label(doneMessage, systemImage: "checkmark.circle.fill")
                            .font(.echoFootnote)
                            .foregroundStyle(.green)
                    } else if !diagnosis.fixes.isEmpty {
                        Button {
                            showPermission = true
                        } label: {
                            Label("Let Echo fix this", systemImage: "wand.and.stars")
                                .font(.echoHeadline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, EchoSpacing.sm)
                                .background(LinearGradient.echoAccent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.md))
                        }
                    }
                }
                .padding(EchoSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.echoSurface)
                .overlay(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg).stroke(Color.echoLavender.opacity(0.5)))
                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
                .accessibilityElement(children: .combine)
            }
        }
        .task { await run() }
        .onDisappear { narrator.stop() }
        .sheet(isPresented: $showPermission) {
            if let diagnosis {
                FixPermissionSheet(diagnosis: diagnosis) { approved in
                    showPermission = false
                    Task { await perform(approved) }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func run() async {
        guard let imageData, diagnosis == nil else { return }
        let look = await ErrorDoctor.quickLook(imageData: imageData)
        guard !look.lines.isEmpty || look.known != nil, let prepared = look.prepared else { return }
        errorLines = look.lines

        // 1. Instant answer from what Echo already knows.
        if let known = look.known {
            diagnosis = known
            speak(known)
        }
        // 2. The AI you chose for "Fixing errors" adds the exact cause and fix.
        thinking = true
        defer { thinking = false }
        do {
            let deep = try await ErrorDoctor.diagnose(prepared: prepared, errorLines: look.lines, known: look.known)
            let first = diagnosis == nil
            diagnosis = deep
            if first { speak(deep) }
        } catch {
            if diagnosis == nil, !look.lines.isEmpty {
                diagnosis = ErrorDiagnosis(
                    title: "There's an error on this screen",
                    cause: "Echo couldn't reach an AI to explain it right now. The steps below are a good start.",
                    steps: ["Read the message — it often names what's missing.", "Close the app and open it again.",
                            "Restart your iPhone if it keeps happening."],
                    fixes: [], source: "Echo", errorText: look.lines.first ?? "")
            } else {
                aiNote = "AI unavailable: \(error.localizedDescription)"
            }
        }
    }

    private func speak(_ d: ErrorDiagnosis) {
        guard speakAloud else { return }
        willSpeak()
        let ask = d.fixes.isEmpty ? "" : " Want me to fix it for you?"
        narrator.speak(text: "I found the problem. \(d.title). \(d.cause)\(ask)")
    }

    private func perform(_ actions: [FixAction]) async {
        guard !actions.isEmpty else { return }
        let message = await FixRunner.run(actions)
        doneMessage = message
        if speakAloud { narrator.speak(text: message) }
    }
}

// MARK: - Permission: Echo lists exactly what it will do, you choose

struct FixPermissionSheet: View {
    let diagnosis: ErrorDiagnosis
    let onDecision: ([FixAction]) -> Void
    @State private var selected: Set<FixAction>

    init(diagnosis: ErrorDiagnosis, onDecision: @escaping ([FixAction]) -> Void) {
        self.diagnosis = diagnosis
        self.onDecision = onDecision
        _selected = State(initialValue: Set(diagnosis.fixes))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Can Echo fix “\(diagnosis.title)” for you? Here's exactly what Echo will do. Untick anything you don't want.")
                        .font(.echoSubheadline)
                }
                Section("Echo will…") {
                    ForEach(diagnosis.fixes, id: \.self) { fix in
                        Button {
                            if selected.contains(fix) { selected.remove(fix) } else { selected.insert(fix) }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(fix) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(.echoLavender)
                                Label(fix.title, systemImage: fix.icon)
                                    .foregroundStyle(.echoTextPrimary)
                            }
                        }
                    }
                }
                Section {
                    Text("Echo never deletes anything or buys anything without asking you first. iOS also lets Echo open Settings for you but not flip switches there — Echo will walk you through those taps.")
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextTertiary)
                }
            }
            .navigationTitle("Permission to fix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { onDecision([]) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Yes, fix it") {
                        onDecision(diagnosis.fixes.filter { selected.contains($0) })
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}

// MARK: - Runs approved fixes

@MainActor
enum FixRunner {
    static func run(_ actions: [FixAction]) async -> String {
        var did: [String] = []
        for action in actions {
            ActivityLog.shared.record(ActivityEntry(batch: UUID(), summary: action.title, icon: action.icon,
                                                    origin: "Error Doctor", status: .handedOff))
            switch action {
            case .freeUpStorage:
                EchoLaunchCenter.shared.request(.photoCleanup)
                did.append("opened Photo Cleanup")
            case .organizeFiles:
                EchoLaunchCenter.shared.request(.fileOrganizer)
                did.append("opened File Cleanup")
            case .openEchoSettings:
                if let url = URL(string: UIApplication.openSettingsURLString) { await UIApplication.shared.open(url) }
                did.append("opened Settings")
            case .liveGuide(let goal):
                EchoLaunchCenter.shared.request(.liveGuideGoal(goal))
                did.append("started a live walk-through")
            case .openLink(_, let link):
                if let url = URL(string: link) { await UIApplication.shared.open(url) }
                did.append("opened the page")
            case .remindLater(let what):
                let plan = AgentPlan(title: "Reminder", explanation: what,
                                     actions: [.createReminder(title: what, dueDate: Date.now.addingTimeInterval(3600))])
                _ = try? await LiveAgentService(origin: "Error Doctor").execute(plan: plan)
                did.append("set a reminder")
            }
        }
        return did.isEmpty ? "Okay." : "Done — I \(did.joined(separator: ", "))."
    }
}

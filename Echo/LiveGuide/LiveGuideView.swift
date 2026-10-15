import SwiftUI

// MARK: - Live Guide screen
// 1. Say what you want to do.  2. Start screen sharing with Echo.
// 3. Go to any app — Echo watches and tells you each next step (banner + voice).

struct LiveGuideView: View {
    @Environment(AppRouter.self) private var router
    @State private var vm = LiveGuideViewModel()
    @AppStorage(GuideNarrator.autoSpeakKey) private var speakAloud = true
    @FocusState private var goalFocused: Bool

    var body: some View {
        ZStack {
            Color.echoBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: EchoSpacing.lg) {
                    header
                    if let session = vm.session, session.status != .ready {
                        progressSection(session)
                    } else {
                        goalSection
                    }
                    howItWorks
                }
                .padding(.horizontal, EchoSpacing.md)
                .padding(.top, EchoSpacing.md)
                .padding(.bottom, EchoSpacing.xxxl)
            }
        }
        .navigationTitle("Live Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.echoBackground, for: .navigationBar)
        .onAppear {
            vm.startObserving()
            if let goal = router.pendingLiveGoal {
                router.pendingLiveGoal = nil
                vm.reset()
                vm.goal = goal
            }
        }
        .onDisappear { vm.stopObserving() }
        .sheet(isPresented: $vm.showPlan) {
            if let plan = vm.offeredPlan {
                AgentPlanView(
                    plan: plan,
                    onConfirm: { Task { await vm.runOfferedPlan() } },
                    onCancel: { vm.showPlan = false }
                )
            }
        }
        .alert("Live Guide", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.xs) {
            Label("Echo watches your screen", systemImage: "eye")
                .font(.echoTitle3)
                .foregroundStyle(.echoTextPrimary)
            Text("Share your screen with Echo and go to any app. Echo tells you the next step out loud and in a banner each time your screen changes.")
                .font(.echoFootnote)
                .foregroundStyle(.echoTextSecondary)
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.md) {
            Text("What do you want to do?")
                .font(.echoHeadline)
                .foregroundStyle(.echoTextPrimary)

            TextField("e.g. Turn on Dark Mode", text: $vm.goal, axis: .vertical)
                .font(.echoBody)
                .lineLimit(1...3)
                .padding(EchoSpacing.md)
                .background(Color.echoSurface)
                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
                .focused($goalFocused)
                .submitLabel(.done)
                .onSubmit { Task { await vm.prepare(speakAloud: speakAloud) } }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: EchoSpacing.xs) {
                    ForEach(vm.suggestions, id: \.self) { suggestion in
                        Button(suggestion) { vm.goal = suggestion }
                            .font(.echoFootnote)
                            .padding(.horizontal, EchoSpacing.sm)
                            .padding(.vertical, 6)
                            .background(Color.echoSurface)
                            .clipShape(Capsule())
                            .foregroundStyle(.echoTextPrimary)
                    }
                }
            }

            if let plan = vm.offeredPlan {
                VStack(alignment: .leading, spacing: EchoSpacing.sm) {
                    Label("Echo can do this for you", systemImage: "wand.and.stars")
                        .font(.echoHeadline)
                        .foregroundStyle(.echoTextPrimary)
                    Text(plan.explanation)
                        .font(.echoFootnote)
                        .foregroundStyle(.echoTextSecondary)
                    EchoButton("Do it for me", systemImage: "checkmark.circle") { vm.showPlan = true }
                    Text("Or let Echo walk you through it below.")
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextTertiary)
                }
                .padding(EchoSpacing.md)
                .background(Color.echoSurface)
                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
            }
            if let message = vm.agentResultMessage {
                Label(message, systemImage: "checkmark.seal")
                    .font(.echoFootnote)
                    .foregroundStyle(.echoTextSecondary)
            }

            if vm.isReadyToBroadcast {
                VStack(alignment: .leading, spacing: EchoSpacing.sm) {
                    Text("Goal: \(vm.session?.goal ?? "")")
                        .font(.echoSubheadline)
                        .foregroundStyle(.echoTextPrimary)
                    BroadcastPickerButton(title: "Start Screen Sharing")
                    Text("In the sheet that opens, make sure **Echo** is selected, tap **Start Broadcast**, then go to the app you need help with.")
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextSecondary)
                    Button("Change goal") { vm.reset() }
                        .font(.echoFootnote)
                }
            } else {
                EchoButton("Set Goal", systemImage: "target") {
                    goalFocused = false
                    Task { await vm.prepare(speakAloud: speakAloud) }
                }
                .disabled(vm.goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Toggle("Speak each step", isOn: $speakAloud)
                .font(.echoSubheadline)
        }
    }

    private func progressSection(_ session: LiveGuideSession) -> some View {
        VStack(alignment: .leading, spacing: EchoSpacing.md) {
            HStack {
                Circle()
                    .fill(vm.isActive ? Color.echoMint : Color.echoTextTertiary)
                    .frame(width: 10, height: 10)
                Text(vm.statusLine)
                    .font(.echoSubheadline)
                    .foregroundStyle(.echoTextSecondary)
            }

            Text("Goal: \(session.goal)")
                .font(.echoHeadline)
                .foregroundStyle(.echoTextPrimary)

            if let notice = session.safetyNotice, !notice.isEmpty {
                Label(notice, systemImage: "exclamationmark.shield")
                    .font(.echoFootnote)
                    .foregroundStyle(.echoWarning)
            }

            if let current = session.currentStep {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.status == .done ? "Finished" : "Step \(session.steps.count)")
                        .font(.echoCaption.weight(.semibold))
                        .foregroundStyle(.echoLavender)
                    Text(current.instruction)
                        .font(.echoTitle3)
                        .foregroundStyle(.echoTextPrimary)
                    if !current.detail.isEmpty {
                        Text(current.detail)
                            .font(.echoFootnote)
                            .foregroundStyle(.echoTextSecondary)
                    }
                }
                .padding(EchoSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.echoSurface)
                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
            }

            if session.steps.count > 1 {
                VStack(alignment: .leading, spacing: EchoSpacing.xs) {
                    Text("Earlier steps")
                        .font(.echoCaption.weight(.semibold))
                        .foregroundStyle(.echoTextTertiary)
                    ForEach(Array(session.steps.dropLast().enumerated()), id: \.element.id) { index, step in
                        Text("\(index + 1). \(step.instruction)")
                            .font(.echoFootnote)
                            .foregroundStyle(.echoTextSecondary)
                    }
                }
            }

            if vm.isActive {
                BroadcastPickerButton(title: "Stop Screen Sharing")
                Text("You can also stop from the red indicator at the top of your screen.")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
            } else {
                EchoButton("New Live Guide", systemImage: "arrow.counterclockwise") { vm.reset() }
            }
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.xs) {
            Text("Good to know")
                .font(.echoCaption.weight(.semibold))
                .foregroundStyle(.echoTextTertiary)
            Text("• Echo only sees your screen while sharing is on — iOS shows a red indicator the whole time.\n• Frames are sent to Echo's guide service to find your next step and aren't stored.\n• iPhone doesn't let Echo tap for you, so it tells you where to tap.\n• Stop sharing before typing passwords or viewing private messages.")
                .font(.echoCaption)
                .foregroundStyle(.echoTextSecondary)
        }
    }
}

import SwiftUI

struct AgentView: View {
    @Environment(AppRouter.self) private var router
    @State private var vm = AgentViewModel()
    @State private var showPlan = false
    @FocusState private var inputFocused: Bool

    // Quick command suggestions
    private let suggestions: [(icon: String, text: String)] = [
        ("person.crop.circle.badge.minus", "Delete duplicate contacts"),
        ("photo.badge.minus",              "Clear old screenshots"),
        ("bell.badge.plus",                "Remind me to follow up tomorrow"),
        ("note.text.badge.plus",           "Save this note: "),
        ("folder.badge.plus",              "Create a folder called Projects"),
        ("photo.on.rectangle",             "List my largest videos")
    ]

    var body: some View {
        ZStack {
            Color.echoBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                historyList
                inputBar
            }
        }
        .navigationTitle("Echo Agent")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.echoBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    vm.reset()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(.echoLavender)
                }
                .accessibilityLabel("New task")
            }
        }
        .sheet(isPresented: $showPlan) {
            if let plan = vm.currentPlan {
                AgentPlanView(
                    plan: plan,
                    onConfirm: {
                        showPlan = false
                        Task { await vm.executePlan() }
                    },
                    onCancel: {
                        showPlan = false
                        vm.phase = .idle
                    }
                )
            }
        }
        .onChange(of: vm.phase) { _, phase in
            if phase == .planReady { showPlan = true }
        }
        .task { await vm.refreshPermissions() }
    }

    // MARK: - History + status area

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: EchoSpacing.md) {
                // Permissions notice if any are missing
                if !vm.contactsGranted || !vm.photosGranted || !vm.remindersGranted {
                    permissionsNotice
                }

                // Phase-driven content
                switch vm.phase {
                case .idle:
                    if vm.history.isEmpty {
                        welcomeState
                    }
                case .analyzing:
                    LoadingStateView(message: "Echo is reading your request…")
                case .planReady:
                    EmptyView() // plan shown in sheet
                case .executing:
                    LoadingStateView(message: "Echo is working on it…")
                case .done:
                    if let result = vm.currentResult {
                        AgentResultCard(result: result)
                    }
                case .failed(let msg):
                    errorCard(message: msg)
                }

                // History
                if !vm.history.isEmpty {
                    VStack(alignment: .leading, spacing: EchoSpacing.sm) {
                        Text("Recent Actions")
                            .font(.echoTitle3)
                            .foregroundStyle(.echoTextPrimary)
                            .padding(.horizontal, EchoSpacing.md)

                        ForEach(vm.history.dropFirst()) { result in
                            AgentResultCard(result: result)
                        }
                    }
                }
            }
            .padding(.horizontal, EchoSpacing.md)
            .padding(.vertical, EchoSpacing.md)
        }
    }

    // MARK: - Welcome / suggestions

    private var welcomeState: some View {
        VStack(spacing: EchoSpacing.lg) {
            VStack(spacing: EchoSpacing.sm) {
                EchoOrb(size: 80)
                    .accessibilityHidden(true)
                Text("What do you need done?")
                    .font(.echoTitle3)
                    .foregroundStyle(.echoTextPrimary)
                    .multilineTextAlignment(.center)
                Text("Echo can manage your contacts, photos, files, and reminders. Tell it what to do — it will show you a plan before acting.")
                    .font(.echoSubheadline)
                    .foregroundStyle(.echoTextSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: EchoSpacing.xs) {
                ForEach(suggestions, id: \.text) { s in
                    Button {
                        vm.commandText = s.text
                        inputFocused = false
                        Task { await vm.analyze() }
                    } label: {
                        HStack(spacing: EchoSpacing.sm) {
                            Image(systemName: s.icon)
                                .font(.echoSubheadline)
                                .foregroundStyle(LinearGradient.echoAccent)
                                .frame(width: 28)
                                .accessibilityHidden(true)
                            Text(s.text)
                                .font(.echoSubheadline)
                                .foregroundStyle(.echoTextPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(EchoSpacing.md)
                        .background(Color.echoSurface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Suggestion: \(s.text)")
                }
            }
        }
        .padding(.top, EchoSpacing.xl)
    }

    // MARK: - Permissions notice

    private var permissionsNotice: some View {
        EchoCard {
            HStack(alignment: .top, spacing: EchoSpacing.sm) {
                Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                    .foregroundStyle(.echoWarning)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Some permissions not yet granted")
                        .font(.echoHeadline)
                        .foregroundStyle(.echoTextPrimary)
                    Text("Echo will ask for permission when you run a task that needs it. You can also enable access now in Settings.")
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextSecondary)
                }
            }
            .padding(EchoSpacing.md)
        }
    }

    // MARK: - Error card

    private func errorCard(message: String) -> some View {
        EchoCard {
            HStack(spacing: EchoSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.echoDestructive)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Something went wrong")
                        .font(.echoHeadline)
                        .foregroundStyle(.echoTextPrimary)
                    Text(message)
                        .font(.echoSubheadline)
                        .foregroundStyle(.echoTextSecondary)
                }
                Spacer()
                Button {
                    vm.reset()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.echoLavender)
                }
                .accessibilityLabel("Try again")
            }
            .padding(EchoSpacing.md)
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.echoSeparator)

            HStack(alignment: .bottom, spacing: EchoSpacing.sm) {
                // Voice button
                VoiceQuestionButton(
                    isRecording: vm.isRecording,
                    onPress: { vm.startVoice() },
                    onRelease: { vm.stopVoice() }
                )
                .frame(width: 52, height: 52)
                .scaleEffect(0.72)

                // Text field
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg)
                        .fill(Color.echoSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg)
                                .strokeBorder(
                                    inputFocused
                                        ? AnyShapeStyle(LinearGradient.echoAccentSubtle)
                                        : AnyShapeStyle(Color.echoSeparator),
                                    lineWidth: inputFocused ? 2 : 1
                                )
                        )

                    if vm.commandText.isEmpty {
                        Text("Tell Echo what to do…")
                            .font(.echoBody)
                            .foregroundStyle(.echoTextTertiary)
                            .padding(.horizontal, EchoSpacing.md)
                            .padding(.vertical, EchoSpacing.sm)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $vm.commandText)
                        .font(.echoBody)
                        .foregroundStyle(.echoTextPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, EchoSpacing.xs)
                        .padding(.vertical, EchoSpacing.xxs)
                        .frame(minHeight: 44, maxHeight: 120)
                        .focused($inputFocused)
                }

                // Run button
                Button {
                    inputFocused = false
                    Task { await vm.analyze() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            vm.commandText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AnyShapeStyle(Color.echoTextTertiary)
                                : AnyShapeStyle(LinearGradient.echoAccent)
                        )
                }
                .disabled(vm.commandText.trimmingCharacters(in: .whitespaces).isEmpty
                          || vm.phase == .analyzing || vm.phase == .executing)
                .accessibilityLabel("Run this task")
            }
            .padding(.horizontal, EchoSpacing.md)
            .padding(.vertical, EchoSpacing.sm)
            .background(Color.echoBackground)
        }
    }
}

#Preview {
    NavigationStack {
        AgentView()
            .environment(AppRouter())
    }
}

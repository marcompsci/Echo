import SwiftUI
import SwiftData

struct AnalyzeView: View {
    let imageData: Data

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @AppStorage("imageRetentionPolicy") private var retentionRaw: String = EchoSession.ImageRetentionPolicy.noSave.rawValue

    @State private var vm: AnalyzeViewModel
    @FocusState private var questionFocused: Bool

    init(imageData: Data) {
        self.imageData = imageData
        _vm = State(initialValue: AnalyzeViewModel())
    }

    private var retentionPolicy: EchoSession.ImageRetentionPolicy {
        EchoSession.ImageRetentionPolicy(rawValue: retentionRaw) ?? .noSave
    }

    var body: some View {
        ZStack {
            Color.echoBackground.ignoresSafeArea()

            switch vm.phase {
            case .analyzing:
                LoadingStateView(message: "Echo is looking for the clearest next step…")
                    .transition(.opacity)
            case .failed(let msg):
                errorView(message: msg)
                    .transition(.opacity)
            default:
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.phase.isAnalyzing)
        .navigationTitle("Analyze")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.echoBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { vm.setImage(imageData) }
        .onChange(of: vm.phase) { _, phase in
            if case .done = phase, let session = vm.savedSession, let response = vm.result {
                router.pendingImageData = vm.selectedImageData
                router.navigateToResult(session: session, response: response)
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: EchoSpacing.lg) {
                // Image preview with replace button
                ImagePickerButton(
                    currentImage: vm.selectedImage,
                    onImageSelected: { data in vm.setImage(data) }
                )

                // Sensitive content warning
                if let warning = vm.sensitiveContentWarning {
                    SensitiveContentWarning(message: warning)
                }

                // Question field
                questionSection

                // Suggested prompts
                promptChips

                // Voice input
                voiceSection

                // Error from voice
                if let err = vm.voiceError {
                    Text(err)
                        .font(.echoFootnote)
                        .foregroundStyle(.echoDestructive)
                        .padding(.horizontal, EchoSpacing.md)
                }

                // CTA
                ctaSection
            }
            .padding(.horizontal, EchoSpacing.md)
            .padding(.top, EchoSpacing.md)
            .padding(.bottom, EchoSpacing.xxxl)
        }
    }

    // MARK: - Question field

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.xs) {
            Text("Your question")
                .font(.echoHeadline)
                .foregroundStyle(.echoTextPrimary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg)
                    .fill(Color.echoSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg)
                            .strokeBorder(
                                questionFocused
                                    ? AnyShapeStyle(LinearGradient.echoAccentSubtle)
                                    : AnyShapeStyle(Color.echoSeparator),
                                lineWidth: questionFocused ? 2 : 1
                            )
                    )

                if vm.question.isEmpty {
                    Text("Ask Echo anything about this screen…")
                        .font(.echoBody)
                        .foregroundStyle(.echoTextTertiary)
                        .padding(.horizontal, EchoSpacing.md)
                        .padding(.vertical, EchoSpacing.sm + 2)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $vm.question)
                    .font(.echoBody)
                    .foregroundStyle(.echoTextPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(.horizontal, EchoSpacing.xs)
                    .padding(.vertical, EchoSpacing.xxs)
                    .frame(minHeight: 90)
                    .focused($questionFocused)
            }
            .frame(minHeight: 90)
            .animation(.easeInOut(duration: 0.2), value: questionFocused)
        }
    }

    // MARK: - Prompt chips

    private var promptChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: EchoSpacing.xs) {
                ForEach(vm.suggestedPrompts, id: \.self) { prompt in
                    Button {
                        vm.apply(prompt: prompt)
                        questionFocused = false
                    } label: {
                        Text(prompt)
                            .font(.echoFootnote)
                            .foregroundStyle(vm.question == prompt ? .white : .echoTextSecondary)
                            .padding(.horizontal, EchoSpacing.sm)
                            .padding(.vertical, EchoSpacing.xxs + 2)
                            .background(
                                vm.question == prompt
                                    ? AnyShapeStyle(LinearGradient.echoAccent)
                                    : AnyShapeStyle(Color.echoSurface)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.echoSeparator, lineWidth: vm.question == prompt ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Suggested prompt: \(prompt)")
                }
            }
            .padding(.horizontal, EchoSpacing.md)
        }
        .padding(.horizontal, -EchoSpacing.md)
    }

    // MARK: - Voice

    private var voiceSection: some View {
        VStack(spacing: EchoSpacing.sm) {
            Divider().background(Color.echoSeparator)
                .padding(.vertical, EchoSpacing.xxs)

            VoiceQuestionButton(
                isRecording: vm.isRecording,
                onPress: { vm.startVoiceInput() },
                onRelease: { vm.stopVoiceInput() }
            )

            if let transcript = vm.voiceTranscript {
                Text("Heard: \"\(transcript)\"")
                    .font(.echoFootnote)
                    .foregroundStyle(.echoTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, EchoSpacing.lg)
            }
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: EchoSpacing.sm) {
            EchoButton(
                "Create My Guide",
                systemImage: "sparkles"
            ) {
                questionFocused = false
                let store = SessionStore(context: modelContext)
                Task { await vm.createGuide(store: store, retentionPolicy: retentionPolicy) }
            }
            .disabled(!vm.canCreateGuide)
            .opacity(vm.canCreateGuide ? 1 : 0.45)
            .accessibilityHint(vm.canCreateGuide ? "" : "Add an image and question to continue")

            Text("Requires an image and at least one question.")
                .font(.echoCaption)
                .foregroundStyle(.echoTextTertiary)
                .opacity(vm.canCreateGuide ? 0 : 1)
        }
    }

    // MARK: - Error view

    private func errorView(message: String) -> some View {
        VStack(spacing: EchoSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.echoWarning)
                .accessibilityHidden(true)

            VStack(spacing: EchoSpacing.xs) {
                Text("Something went wrong")
                    .font(.echoTitle3)
                    .foregroundStyle(.echoTextPrimary)
                Text(message)
                    .font(.echoSubheadline)
                    .foregroundStyle(.echoTextSecondary)
                    .multilineTextAlignment(.center)
            }

            EchoButton("Try Again") {
                vm.phase = .idle
            }
            .padding(.horizontal, EchoSpacing.xl)
        }
        .padding(EchoSpacing.xl)
    }
}

// MARK: - Phase helper

extension AnalyzeViewModel.Phase {
    var isAnalyzing: Bool {
        if case .analyzing = self { return true }
        return false
    }
}

extension AnalyzeViewModel.Phase: Equatable {
    static func == (lhs: AnalyzeViewModel.Phase, rhs: AnalyzeViewModel.Phase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.analyzing, .analyzing), (.done, .done): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

#Preview {
    let data = UIImage(systemName: "iphone")!.jpegData(compressionQuality: 0.8)!
    return NavigationStack {
        AnalyzeView(imageData: data)
            .environment(AppRouter())
            .modelContainer(for: EchoSession.self, inMemory: true)
    }
}

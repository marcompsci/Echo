import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var vm = HomeViewModel()
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showHowItWorks = false
    @State private var isLoadingPhoto = false

    var body: some View {
        ZStack {
            Color.echoBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: EchoSpacing.lg) {
                    headerSection
                    agentHeroCard       // Echo Agent — primary feature
                    Divider().background(Color.echoSeparator).padding(.horizontal, EchoSpacing.lg)
                    guideSection        // Visual guide flow (secondary)
                    recentSection
                }
                .padding(.horizontal, EchoSpacing.md)
                .padding(.top, EchoSpacing.md)
                .padding(.bottom, EchoSpacing.xxxl)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            vm.loadSessions(from: modelContext)
            vm.checkClipboard()
            checkForSharedImage()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            isLoadingPhoto = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    router.navigateToAnalyze(imageData: data)
                }
                isLoadingPhoto = false
                selectedPhoto = nil
            }
        }
        .sheet(isPresented: $showHowItWorks) {
            HowItWorksSheet()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Echo")
                    .font(.echoTitle2)
                    .foregroundStyle(LinearGradient.echoAccent)
                Text(vm.greeting)
                    .font(.echoSubheadline)
                    .foregroundStyle(.echoTextSecondary)
            }
            Spacer()
            Button {
                router.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.echoTitle3)
                    .foregroundStyle(.echoTextSecondary)
            }
            .accessibilityLabel("Settings")
        }
    }

    // MARK: - Agent hero (primary)

    private var agentHeroCard: some View {
        Button { router.navigateToAgent() } label: {
            EchoCard(elevated: true) {
                HStack(spacing: EchoSpacing.lg) {
                    EchoOrb(size: 72)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: EchoSpacing.xs) {
                        HStack(spacing: EchoSpacing.xs) {
                            Text("Echo Agent")
                                .font(.echoTitle3)
                                .foregroundStyle(.echoTextPrimary)
                            Text("NEW")
                                .font(.echoCaption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LinearGradient.echoAccent)
                                .clipShape(Capsule())
                        }

                        Text("Manage contacts, photos, files, and reminders with a single command.")
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)

                        HStack(spacing: EchoSpacing.xxs) {
                            ForEach(["Contacts", "Photos", "Files", "Reminders"], id: \.self) { chip in
                                Text(chip)
                                    .font(.echoCaption2)
                                    .foregroundStyle(.echoLavender)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.echoLavender.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.echoHeadline)
                        .foregroundStyle(.echoTextTertiary)
                        .accessibilityHidden(true)
                }
                .padding(EchoSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Echo Agent — manage contacts, photos, files, and reminders")
        .accessibilityHint("Open the agent to give a command")
    }

    // MARK: - Guide section (secondary)

    private var guideSection: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            Text("Visual Guide")
                .font(.echoTitle3)
                .foregroundStyle(.echoTextPrimary)

            Text("Import a screenshot and ask Echo to explain it with numbered steps.")
                .font(.echoCaption)
                .foregroundStyle(.echoTextSecondary)

            VStack(spacing: EchoSpacing.xs) {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    ActionRowVisual(
                        systemImage: "photo.badge.plus",
                        title: "Import a Screenshot",
                        subtitle: "Choose from your photo library",
                        isPrimary: true,
                        isLoading: isLoadingPhoto
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingPhoto)
                .accessibilityLabel("Import a screenshot")
                .accessibilityHint("Choose an image from your photo library")

                if vm.clipboardImage != nil {
                    Button {
                        if let data = vm.consumeClipboardImage() {
                            router.navigateToAnalyze(imageData: data)
                        }
                    } label: {
                        ActionRowVisual(
                            systemImage: "doc.on.clipboard",
                            title: "Paste from Clipboard",
                            subtitle: "Use the image you just copied",
                            isPrimary: false,
                            isLoading: false
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Paste from Clipboard")
                }

                Label {
                    Text("Echo only analyzes what you choose to share.")
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextTertiary)
                } icon: {
                    Image(systemName: "lock.fill")
                        .font(.echoCaption)
                        .foregroundStyle(.echoMint)
                }
                .padding(.top, EchoSpacing.xxs)
            }
        }
    }

    // MARK: - Recent guides

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            HStack {
                Text("Recent Guides")
                    .font(.echoTitle3)
                    .foregroundStyle(.echoTextPrimary)
                Spacer()
                Button {
                    showHowItWorks = true
                } label: {
                    Text("How Echo works")
                        .font(.echoFootnote)
                        .foregroundStyle(.echoLavender)
                }
                .accessibilityLabel("How Echo works — open information sheet")
            }

            if vm.recentSessions.isEmpty {
                EmptyStateView(
                    systemImage: "square.stack.3d.up.slash",
                    title: "Your guides will appear here",
                    subtitle: "Import a screenshot and ask Echo a question to get started."
                )
                .frame(maxWidth: .infinity)
                .background(Color.echoSurface)
                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
            } else {
                VStack(spacing: EchoSpacing.xs) {
                    ForEach(vm.recentSessions) { session in
                        if let response = session.decodedGuideResponse {
                            Button {
                                router.pendingImageData = session.imageData
                                router.navigateToResult(session: session, response: response)
                            } label: {
                                RecentSessionRow(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func checkForSharedImage() {
        if let data = vm.checkForSharedImage() {
            router.navigateToAnalyze(imageData: data)
        }
    }
}

// MARK: - Non-interactive row visual (used inside PhotosPicker label)

private struct ActionRowVisual: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let isPrimary: Bool
    let isLoading: Bool

    var body: some View {
        HStack(spacing: EchoSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: EchoSpacing.Corner.md)
                    .fill(isPrimary ? LinearGradient.echoAccent : AnyShapeStyle(Color.echoSurfaceElevated))
                    .frame(width: 48, height: 48)
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isPrimary ? .white : AnyShapeStyle(LinearGradient.echoAccent))
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextPrimary)
                Text(subtitle)
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.echoFootnote.weight(.semibold))
                .foregroundStyle(.echoTextTertiary)
                .accessibilityHidden(true)
        }
        .padding(EchoSpacing.md)
        .background(Color.echoSurface)
        .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
        .overlay(
            RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl)
                .strokeBorder(
                    isPrimary
                        ? AnyShapeStyle(LinearGradient.echoAccentSubtle)
                        : AnyShapeStyle(Color.echoSeparator),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - How It Works sheet

private struct HowItWorksSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let steps: [(icon: String, title: String, detail: String)] = [
        ("sparkles", "Echo Agent", "Tell Echo what to do in plain language. It reads your request, shows you a full plan, and only acts after you confirm."),
        ("photo.badge.plus", "Share a screenshot or photo", "Import any image from your library or paste from your clipboard. Echo never accesses your photos without your action."),
        ("text.bubble", "Ask your question", "Type what you want to know, or hold the voice button and speak naturally."),
        ("checkmark.circle", "Review, confirm, done", "Every suggested action — including agent tasks — shows you exactly what will happen before you confirm.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.echoBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: EchoSpacing.lg) {
                        EchoOrb(size: 72).padding(.top, EchoSpacing.lg)
                        VStack(spacing: EchoSpacing.md) {
                            ForEach(steps, id: \.title) { step in
                                HStack(alignment: .top, spacing: EchoSpacing.md) {
                                    Image(systemName: step.icon)
                                        .font(.echoTitle3)
                                        .foregroundStyle(LinearGradient.echoAccent)
                                        .frame(width: 36)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.title)
                                            .font(.echoHeadline)
                                            .foregroundStyle(.echoTextPrimary)
                                        Text(step.detail)
                                            .font(.echoSubheadline)
                                            .foregroundStyle(.echoTextSecondary)
                                    }
                                }
                                .padding(EchoSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.echoSurface)
                                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
                            }
                        }
                        .padding(.horizontal, EchoSpacing.md)
                    }
                    .padding(.bottom, EchoSpacing.xxl)
                }
            }
            .navigationTitle("How Echo works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.echoBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(.echoLavender)
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(AppRouter())
        .modelContainer(for: EchoSession.self, inMemory: true)
}

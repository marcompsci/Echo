import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Home (calm & premium)
//
//   Greeting by name · light/dark toggle
//   Big orb: tap to talk, with a few things to try
//   "Do something" grid: Screenshot · Live Guide · Agent · Cleanup
//   Continue where you left off (recent guides)

struct HomeView: View {
    @Environment(AppRouter.self)   private var router
    @Environment(\.modelContext)   private var modelContext
    @Environment(PetState.self)    private var petState
    @AppStorage("echoPetEnabled")  private var petEnabled = false
    @AppStorage(UserProfile.nameKey) private var userName = ""
    @State private var vm = HomeViewModel()
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var showHowItWorks = false
    @State private var isLoadingPhoto = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let suggestions = [
        "What do I tap here?",
        "Remind me to pay rent Friday",
        "Walk me through turning on Wi-Fi",
        "Clean up my screenshots"
    ]

    var body: some View {
        ZStack {
            EchoAmbientBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: EchoSpacing.xl) {
                    header
                    orbHero
                    suggestionChips
                    actionGrid
                    clipboardBanner
                    recentSection
                    privacyFooter
                }
                .padding(.horizontal, EchoSpacing.gutter)
                .padding(.top, EchoSpacing.sm)
                .padding(.bottom, EchoSpacing.xxxl)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 12)
            }
            .scrollIndicators(.hidden)

            if petEnabled {
                GeometryReader { geo in
                    FloatingPetView(containerSize: geo.size)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            vm.loadSessions(from: modelContext)
            vm.checkClipboard()
            checkForSharedImage()
            withAnimation(EchoMotion.spring.delay(0.05)) { appeared = true }
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

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.greeting.uppercased())
                    .font(.echoEyebrow)
                    .tracking(1.2)
                    .foregroundStyle(.echoTextTertiary)
                Text(userName.trimmingCharacters(in: .whitespaces).isEmpty ? "Hi there" : userName)
                    .font(.echoDisplay)
                    .foregroundStyle(.echoTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
            AppearanceToggle()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Orb hero

    private var orbHero: some View {
        Button {
            router.heyEchoGreeting = UserProfile.helpGreeting
            router.heyEchoText = nil
            router.showHeyEcho = true
        } label: {
            VStack(spacing: EchoSpacing.md) {
                EchoOrbView(size: 168)
                    .padding(.top, EchoSpacing.lg)
                VStack(spacing: 4) {
                    Text("Tap to talk to Echo")
                        .font(.echoTitle3)
                        .foregroundStyle(.echoTextPrimary)
                    Text("Ask anything, get help with your screen, or have Echo do it.")
                        .font(.echoSubheadline)
                        .foregroundStyle(.echoTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, EchoSpacing.lg)
                Label("Listening starts when you tap", systemImage: "mic.fill")
                    .font(.echoCaption.weight(.semibold))
                    .foregroundStyle(.echoLavender)
                    .padding(.horizontal, EchoSpacing.sm)
                    .padding(.vertical, 6)
                    .background(Color.echoLavender.opacity(0.12), in: Capsule())
                    .padding(.bottom, EchoSpacing.lg)
            }
            .frame(maxWidth: .infinity)
            .echoGlass(cornerRadius: EchoSpacing.Corner.xxl, interactive: true)
        }
        .buttonStyle(.echoPress)
        .accessibilityLabel("Talk to Echo")
        .accessibilityHint("Opens Echo listening")
    }

    private var suggestionChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: EchoSpacing.xs) {
                ForEach(suggestions, id: \.self) { text in
                    Button {
                        router.heyEchoGreeting = nil
                        router.heyEchoText = text
                        router.showHeyEcho = true
                    } label: {
                        Text(text)
                            .font(.echoFootnote.weight(.medium))
                            .foregroundStyle(.echoTextPrimary)
                            .padding(.horizontal, EchoSpacing.sm)
                            .padding(.vertical, EchoSpacing.xs)
                            .echoGlass(cornerRadius: EchoSpacing.Corner.full)
                    }
                    .buttonStyle(.echoPress)
                    .accessibilityHint("Asks Echo this")
                }
            }
            .padding(.horizontal, EchoSpacing.gutter)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -EchoSpacing.gutter)
    }

    // MARK: Action grid

    private var actionGrid: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            EchoSectionHeader(title: "Do something", action: ("How Echo works", { showHowItWorks = true }))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: EchoSpacing.sm), GridItem(.flexible(), spacing: EchoSpacing.sm)],
                      spacing: EchoSpacing.sm) {
                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    HomeTile(icon: "camera.viewfinder", title: "Explain a screenshot",
                             subtitle: "Steps + fixes for errors", tint: .echoLavender, isLoading: isLoadingPhoto)
                }
                .buttonStyle(.echoPress)
                .disabled(isLoadingPhoto)

                Button { router.navigateToLiveGuide() } label: {
                    HomeTile(icon: "dot.radiowaves.left.and.right", title: "Live Guide",
                             subtitle: "Echo watches and coaches", tint: .echoMint)
                }
                .buttonStyle(.echoPress)

                Button { router.navigateToAgent() } label: {
                    HomeTile(icon: "wand.and.stars", title: "Echo Agent",
                             subtitle: "Reminders, texts, events", tint: .echoLavender)
                }
                .buttonStyle(.echoPress)

                Button { router.path.append(EchoRoute.photoCleanup) } label: {
                    HomeTile(icon: "sparkles.rectangle.stack", title: "Cleanup",
                             subtitle: "Photos & files, your call", tint: .echoMint)
                }
                .buttonStyle(.echoPress)
            }
        }
    }

    @ViewBuilder private var clipboardBanner: some View {
        if vm.clipboardImage != nil {
            Button {
                if let data = vm.consumeClipboardImage() { router.navigateToAnalyze(imageData: data) }
            } label: {
                HStack(spacing: EchoSpacing.sm) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .foregroundStyle(.echoLavender)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You copied an image").font(.echoSubheadline.weight(.semibold)).foregroundStyle(.echoTextPrimary)
                        Text("Ask Echo about it").font(.echoCaption).foregroundStyle(.echoTextSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill").font(.echoTitle3).foregroundStyle(.echoLavender)
                }
                .padding(EchoSpacing.md)
                .echoGlass(cornerRadius: EchoSpacing.Corner.lg, tint: .echoLavender.opacity(0.15))
            }
            .buttonStyle(.echoPress)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: Recent

    @ViewBuilder private var recentSection: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            EchoSectionHeader(title: "Pick up where you left off")
            if vm.recentSessions.isEmpty {
                HStack(spacing: EchoSpacing.sm) {
                    Image(systemName: "sparkles").foregroundStyle(.echoLavender)
                    Text("Your guides will show up here after you ask Echo about a screenshot.")
                        .font(.echoFootnote)
                        .foregroundStyle(.echoTextSecondary)
                }
                .padding(EchoSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .echoGlass(cornerRadius: EchoSpacing.Corner.lg)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: EchoSpacing.sm) {
                        ForEach(vm.recentSessions) { session in
                            if let response = session.decodedGuideResponse {
                                Button {
                                    router.pendingImageData = session.imageData
                                    router.navigateToResult(session: session, response: response)
                                } label: {
                                    RecentGuideCard(session: session)
                                }
                                .buttonStyle(.echoPress)
                            }
                        }
                    }
                    .padding(.horizontal, EchoSpacing.gutter)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -EchoSpacing.gutter)
            }
        }
    }

    private var privacyFooter: some View {
        Label("Echo only sees what you choose to share. Privacy Shield hides card numbers and passwords before anything leaves your iPhone.",
              systemImage: "lock.shield.fill")
            .font(.echoCaption)
            .foregroundStyle(.echoTextTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func checkForSharedImage() {
        if let data = vm.checkForSharedImage() {
            router.navigateToAnalyze(imageData: data)
        }
    }
}

// MARK: - Tiles & cards

private struct HomeTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            ZStack {
                Circle().fill(tint.opacity(0.16)).frame(width: 40, height: 40)
                if isLoading { ProgressView() } else {
                    Image(systemName: icon).font(.echoHeadline).foregroundStyle(tint)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(EchoSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .echoGlass(cornerRadius: EchoSpacing.Corner.xl)
        .accessibilityElement(children: .combine)
    }
}

private struct RecentGuideCard: View {
    let session: EchoSession

    var body: some View {
        VStack(alignment: .leading, spacing: EchoSpacing.xs) {
            Group {
                if let data = session.imageData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack {
                        LinearGradient.echoAccentSubtle
                        Image(systemName: "text.bubble").font(.echoTitle3).foregroundStyle(.echoLavender)
                    }
                }
            }
            .frame(width: 168, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.md, style: .continuous))

            Text(session.questionPreview)
                .font(.echoFootnote.weight(.semibold))
                .foregroundStyle(.echoTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 168, alignment: .leading)
            Text(session.createdAt.formatted(.relative(presentation: .named)))
                .font(.echoCaption2)
                .foregroundStyle(.echoTextTertiary)
        }
        .padding(EchoSpacing.xs)
        .echoGlass(cornerRadius: EchoSpacing.Corner.lg)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - How It Works sheet

private struct HowItWorksSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let steps: [(icon: String, title: String, detail: String)] = [
        ("sparkles",         "Echo Agent",                  "Tell Echo what to do in plain language. It reads your request, shows you a full plan, and only acts after you confirm."),
        ("photo.badge.plus", "Share a screenshot or photo", "Import any image from your library or paste from your clipboard. Echo never accesses your photos without your action."),
        ("text.bubble",      "Ask your question",           "Type what you want to know, or hold the voice button and speak naturally."),
        ("checkmark.circle", "Review, confirm, done",       "Every suggested action — including agent tasks — shows you exactly what will happen before you confirm.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                EchoAmbientBackground()
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
                                .echoGlass(cornerRadius: EchoSpacing.Corner.lg)
                            }
                        }
                        .padding(.horizontal, EchoSpacing.gutter)
                    }
                    .padding(.bottom, EchoSpacing.xxl)
                }
            }
            .navigationTitle("How Echo works")
            .navigationBarTitleDisplayMode(.inline)
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
        .environment(PetState())
        .modelContainer(for: EchoSession.self, inMemory: true)
}

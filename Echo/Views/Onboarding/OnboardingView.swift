import SwiftUI

// MARK: - Onboarding (calm & premium)
//
// One glowing orb stays on screen the whole time and gently changes size as
// you move through: Meet Echo → Privacy → Your name → Connect → Ready.
// Every page has a clear button, a Back, and soft haptics.

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var page = 0
    @AppStorage(UserProfile.nameKey) private var userName = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pageCount = 5

    var body: some View {
        ZStack {
            EchoAmbientBackground()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, EchoSpacing.md)
                    .padding(.top, EchoSpacing.xs)

                EchoOrbView(size: orbSize)
                    .padding(.top, page == 0 ? EchoSpacing.xxl : EchoSpacing.md)
                    .animation(reduceMotion ? nil : EchoMotion.spring, value: page)
                    .accessibilityHidden(true)

                TabView(selection: $page) {
                    MeetPage().tag(0)
                    PrivacyPage().tag(1)
                    NamePage(onNext: next).tag(2)
                    ConnectPage().tag(3)
                    ReadyPage().tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : EchoMotion.spring, value: page)

                EchoButton(buttonTitle, systemImage: page == pageCount - 1 ? "sparkles" : nil) { next() }
                    .padding(.horizontal, EchoSpacing.lg)
                    .padding(.bottom, EchoSpacing.lg)
                    .accessibilityHint(page == pageCount - 1 ? "Opens Echo" : "Next page")
            }
        }
        .sensoryFeedback(.selection, trigger: page)
    }

    private var orbSize: CGFloat {
        switch page {
        case 0: return 180
        case 4: return 150
        default: return 96
        }
    }

    private var buttonTitle: String {
        switch page {
        case 0: return "Get started"
        case 2: return userName.trimmingCharacters(in: .whitespaces).isEmpty ? "Skip" : "Continue"
        case 3: return AccountService.shared.isSignedIn ? "Continue" : "Skip for now"
        case 4: return "Start using Echo"
        default: return "Continue"
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                withAnimation(EchoMotion.spring) { page = max(0, page - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextSecondary)
                    .frame(width: 36, height: 36)
                    .echoGlass(cornerRadius: 18)
            }
            .opacity(page == 0 ? 0 : 1)
            .disabled(page == 0)
            .accessibilityLabel("Back")

            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Capsule()
                        .fill(i <= page ? AnyShapeStyle(LinearGradient.echoAccent) : AnyShapeStyle(Color.echoTextTertiary.opacity(0.4)))
                        .frame(width: i == page ? 22 : 7, height: 7)
                }
            }
            .animation(EchoMotion.spring, value: page)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(page + 1) of \(pageCount)")
            Spacer()
            AppearanceToggle()
        }
    }

    private func next() {
        if page < pageCount - 1 {
            withAnimation(EchoMotion.spring) { page += 1 }
        } else {
            finish()
        }
    }

    /// Echo says hello (by name) the moment onboarding finishes.
    private func finish() {
        // Open the app first; the welcome is spoken a moment later so nothing can hold up the switch.
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        onComplete()
        let name = UserProfile.name
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            welcomeNarrator.speak(text: name.isEmpty ? "Hi, I'm Echo. I'm here whenever you need me."
                                                     : "Hi \(name), I'm Echo. I'm here whenever you need me.")
        }
    }
}

/// Kept outside the view so the greeting keeps playing after onboarding closes.
@MainActor private let welcomeNarrator = GuideNarrator()

// MARK: - Shared page layout

private struct PageText: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: EchoSpacing.sm) {
            Text(eyebrow.uppercased())
                .font(.echoEyebrow)
                .tracking(1.4)
                .foregroundStyle(.echoLavender)
            Text(title)
                .font(.echoDisplay)
                .foregroundStyle(.echoTextPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(.echoCallout)
                .foregroundStyle(.echoTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, EchoSpacing.lg)
    }
}

// MARK: - 1. Meet Echo

private struct MeetPage: View {
    var body: some View {
        VStack(spacing: EchoSpacing.lg) {
            PageText(eyebrow: "Meet Echo",
                     title: "Help for anything\non your iPhone",
                     subtitle: "Show Echo your screen, ask out loud, and it points to exactly what to tap — or does it for you, with your OK.")
            Spacer()
        }
    }
}

// MARK: - 2. Privacy

private struct PrivacyPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: EchoSpacing.lg) {
                PageText(eyebrow: "Your privacy",
                         title: "You choose what\nEcho sees",
                         subtitle: "Echo only looks at screenshots and questions you share on purpose.")
                PrivacyPromiseCard()
                    .padding(.horizontal, EchoSpacing.lg)
            }
            .padding(.top, EchoSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - 3. Your name

private struct NamePage: View {
    var onNext: () -> Void
    @AppStorage(UserProfile.nameKey) private var userName = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: EchoSpacing.lg) {
            PageText(eyebrow: "Say hello",
                     title: "What should Echo\ncall you?",
                     subtitle: "Echo greets you by name when you tap it.")
            TextField("Your first name", text: $userName)
                .font(.echoTitle3)
                .multilineTextAlignment(.center)
                .textContentType(.givenName)
                .submitLabel(.next)
                .padding(EchoSpacing.md)
                .echoGlass(cornerRadius: EchoSpacing.Corner.lg)
                .focused($focused)
                .onSubmit { focused = false; onNext() }
                .padding(.horizontal, EchoSpacing.lg)
            Spacer()
        }
        .padding(.top, EchoSpacing.lg)
        .contentShape(Rectangle())
        .onTapGesture { focused = false }
    }
}

// MARK: - 4. Connect

private struct ConnectPage: View {
    var body: some View {
        ScrollView {
            VStack(spacing: EchoSpacing.lg) {
                PageText(eyebrow: "Optional",
                         title: "Connect an account",
                         subtitle: "Keep your guides and settings with you. You can do this later in Settings.")
                ConnectAccountsView(onDone: {})
                    .padding(EchoSpacing.md)
                    .echoGlass(cornerRadius: EchoSpacing.Corner.xl)
                    .padding(.horizontal, EchoSpacing.lg)
            }
            .padding(.top, EchoSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - 5. Ready

private struct ReadyPage: View {
    @AppStorage(UserProfile.nameKey) private var userName = ""
    private let ways: [(icon: String, title: String, detail: String)] = [
        ("mic.fill", "Talk", "Tap the orb or say “Hey Siri, Hey Echo”"),
        ("camera.viewfinder", "Show", "Share a screenshot — Echo explains and fixes errors"),
        ("dot.radiowaves.left.and.right", "Guide", "Live Guide watches and tells you each tap"),
        ("checkmark.shield", "Stay in control", "Echo asks before it does anything")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: EchoSpacing.lg) {
                PageText(eyebrow: "You're all set",
                         title: userName.trimmingCharacters(in: .whitespaces).isEmpty ? "Ready when you are" : "Ready, \(userName.trimmingCharacters(in: .whitespaces))",
                         subtitle: "Here's how to use Echo.")
                VStack(spacing: 0) {
                    ForEach(Array(ways.enumerated()), id: \.offset) { i, way in
                        HStack(spacing: EchoSpacing.md) {
                            Image(systemName: way.icon)
                                .font(.echoHeadline)
                                .foregroundStyle(.echoLavender)
                                .frame(width: 32, height: 32)
                                .background(Color.echoLavender.opacity(0.14), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(way.title).font(.echoHeadline).foregroundStyle(.echoTextPrimary)
                                Text(way.detail).font(.echoCaption).foregroundStyle(.echoTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(EchoSpacing.md)
                        if i < ways.count - 1 { Divider().padding(.leading, 64) }
                    }
                }
                .echoGlass(cornerRadius: EchoSpacing.Corner.xl)
                .padding(.horizontal, EchoSpacing.lg)
            }
            .padding(.top, EchoSpacing.lg)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}

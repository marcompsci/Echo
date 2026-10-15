import SwiftUI
import SwiftData
import AVFAudio
import Speech

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss
    @Environment(PetState.self)  private var petState
    @State private var vm = SettingsViewModel()
    @AppStorage("imageRetentionPolicy") private var retentionRaw: String = EchoSession.ImageRetentionPolicy.noSave.rawValue
    @AppStorage("echoPetEnabled")       private var petEnabled = false
    @AppStorage(GuideEngine.storageKey)  private var engineRaw: String = GuideEngine.automatic.rawValue
    @AppStorage(GuideNarrator.autoSpeakKey) private var speakAloud = true
    @AppStorage(UserProfile.nameKey) private var userName = ""
    @AppStorage(EchoPresence.enabledKey) private var presenceEnabled = false
    @AppStorage(DevInspector.enabledKey) private var developerMode = false
    @State private var shieldOn = PrivacyShield.isEnabled
    @State private var memory = EchoMemory.shared
    @State private var skills = EchoSkillStore.shared

    private var retentionPolicy: Binding<EchoSession.ImageRetentionPolicy> {
        Binding(
            get: { EchoSession.ImageRetentionPolicy(rawValue: retentionRaw) ?? .noSave },
            set: { retentionRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.echoBackground.ignoresSafeArea()
                List {
                    accountSection
                    intelligenceSection
                    personalSection
                    trustSection
                    petSection
                    dataSection
                    permissionsSection
                    developerSection
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.echoBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.echoLavender)
                }
            }
            .onAppear { vm.refresh() }
            .confirmationDialog(
                "Delete all guides?",
                isPresented: $vm.showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All Guides", role: .destructive) {
                    let store = SessionStore(context: modelContext)
                    vm.deleteAllGuides(store: store)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes all guide text and any saved images. Sessions are deleted immediately and cannot be recovered.")
            }
            .alert("All guides deleted", isPresented: .constant(vm.successMessage != nil)) {
                Button("OK") { vm.successMessage = nil }
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    // MARK: - Account section

    private var intelligenceSection: some View {
        Section {
            Picker("Guide engine", selection: $engineRaw) {
                ForEach(GuideEngine.allCases) { engine in
                    Text(engine.title).tag(engine.rawValue)
                }
            }
            Text((GuideEngine(rawValue: engineRaw) ?? .automatic).detail)
                .font(.echoFootnote)
                .foregroundStyle(.echoTextSecondary)

            Toggle("Read guides aloud", isOn: $speakAloud)

            NavigationLink {
                HeyEchoSetupView()
            } label: {
                Label("Set up Hey Echo", systemImage: "waveform.circle")
            }

            Label {
                Text(AppleIntelligence.statusDescription)
                    .font(.echoFootnote)
                    .foregroundStyle(.echoTextSecondary)
            } icon: {
                Image(systemName: AppleIntelligence.isAvailable ? "apple.intelligence" : "exclamationmark.circle")
                    .foregroundStyle(.echoLavender)
            }
        } header: {
            Text("Apple Intelligence")
        } footer: {
            Text("Echo Agent plans tasks and cleans up voice questions with Apple Intelligence on-device when it's available.")
        }
    }

    // MARK: - Echo knows you

    private var personalSection: some View {
        Section {
            NavigationLink {
                MemoryView()
            } label: {
                HStack {
                    Label("What Echo Remembers", systemImage: "brain.head.profile")
                    Spacer()
                    Text(memory.isEnabled ? "\(memory.facts.count)" : "Off")
                        .font(.echoFootnote)
                        .foregroundStyle(.echoTextTertiary)
                }
            }
            NavigationLink {
                SkillsView()
            } label: {
                HStack {
                    Label("Echo Skills", systemImage: "sparkles.rectangle.stack")
                    Spacer()
                    Text("\(skills.skills.count)")
                        .font(.echoFootnote)
                        .foregroundStyle(.echoTextTertiary)
                }
            }
            NavigationLink {
                VoiceSettingsView()
            } label: {
                Label("Voice & Simple Mode", systemImage: "person.wave.2")
            }
            NavigationLink {
                ConnectAIView()
            } label: {
                Label("Connect AI (Claude, ChatGPT, Grok, Muse)", systemImage: "link.circle")
            }
            NavigationLink {
                PhotoCleanupView()
            } label: {
                Label("Photo Cleanup", systemImage: "photo.stack")
            }
            NavigationLink {
                FileCleanupView()
            } label: {
                Label("File Cleanup", systemImage: "folder.badge.gearshape")
            }
        } header: {
            Text("Echo Knows You")
        } footer: {
            Text("Memory, your own voice commands, and how Echo talks. All stored on this iPhone.")
        }
        .listRowBackground(Color.echoSurface)
    }

    // MARK: - Trust & privacy

    private var trustSection: some View {
        Section {
            Toggle(isOn: $shieldOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Privacy Shield", systemImage: "eye.slash")
                    Text("Blacks out card numbers, SSNs, bank numbers, passwords and secret keys on your iPhone before a screenshot or live frame is sent.")
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextTertiary)
                }
            }
            .tint(Color.echoLavender)
            .onChange(of: shieldOn) { _, on in PrivacyShield.setEnabled(on) }

            NavigationLink {
                ActivityLogView()
            } label: {
                Label("Trust & Undo", systemImage: "checkmark.shield")
            }
        } header: {
            Text("Trust & Privacy")
        } footer: {
            Text("See everything Echo did, undo what it created, and choose how independent Echo is.")
        }
        .listRowBackground(Color.echoSurface)
    }

    // MARK: - Developer

    private var developerSection: some View {
        Section {
            Toggle("Developer Mode", isOn: $developerMode)
                .tint(Color.echoLavender)
            if developerMode {
                NavigationLink {
                    DevInspectorView()
                } label: {
                    Label("Request Inspector & Hooks", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
        } header: {
            Text("Developers")
        } footer: {
            Text("See which model answered, how long it took, what Privacy Shield removed, and Echo's links and Shortcuts actions you can build on.")
        }
        .listRowBackground(Color.echoSurface)
    }

    private var accountSection: some View {
        Section("Account") {
            TextField("Your name (Echo greets you with it)", text: $userName)
                .textContentType(.givenName)
            ConnectAccountsView()
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            NavigationLink {
                FeedbackView()
            } label: {
                Label("Send Feedback", systemImage: "bubble.left.and.text.bubble.right")
            }
        }
        .listRowBackground(Color.echoSurface)
    }

    // MARK: - Digital pet section

    private var petSection: some View {
        Section {
            Toggle(isOn: $petEnabled) {
                Label("Echo Pet", systemImage: "pawprint.fill")
                    .foregroundStyle(.echoTextPrimary)
            }
            .tint(Color.echoLavender)

            if petEnabled {
                NavigationLink {
                    PetCustomizationView(pet: petState)
                } label: {
                    HStack {
                        Label("Customize \(petState.name)", systemImage: "paintpalette")
                            .foregroundStyle(.echoTextPrimary)
                        Spacer()
                        PetCharacterView(
                            mood: petState.mood,
                            bodyColor: petState.bodyColor,
                            accessory: petState.accessory,
                            isBlinking: false,
                            pupilOffset: .zero,
                            isExcited: false,
                            size: 36
                        )
                        .accessibilityHidden(true)
                    }
                }
            }

            if petEnabled {
                Toggle(isOn: $presenceEnabled) {
                    Label("Echo on Lock Screen & Dynamic Island", systemImage: "platter.filled.top.iphone")
                        .foregroundStyle(.echoTextPrimary)
                }
                .tint(Color.echoLavender)
                .onChange(of: presenceEnabled) { _, on in
                    if on { EchoPresence.start() } else { EchoPresence.stop() }
                }
                if presenceEnabled {
                    Text("Echo's orb stays in the Dynamic Island and on your Lock Screen, shows what Echo is doing, and opens Echo listening when you tap it. Turn it off here anytime.")
                        .font(.echoCaption)
                        .foregroundStyle(.echoTextTertiary)
                }
            }

            Text("Your pet lives on the home screen. Tap it to talk to Echo, hold to feed or customize, and drag it out of the way when needed.")
                .font(.echoCaption)
                .foregroundStyle(.echoTextTertiary)
        } header: {
            Text("Digital Pet")
        }
        .listRowBackground(Color.echoSurface)
    }

    // MARK: - Data section

    @ViewBuilder private var dataSection: some View {
        Section {
            VStack(alignment: .leading, spacing: EchoSpacing.xs) {
                Text("Image retention")
                    .font(.echoSubheadline)
                    .foregroundStyle(.echoTextPrimary)

                ForEach(EchoSession.ImageRetentionPolicy.allCases, id: \.rawValue) { policy in
                    Button {
                        retentionPolicy.wrappedValue = policy
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(policy.label)
                                    .font(.echoSubheadline)
                                    .foregroundStyle(.echoTextPrimary)
                                Text(policy.detail)
                                    .font(.echoCaption)
                                    .foregroundStyle(.echoTextSecondary)
                            }
                            Spacer()
                            if retentionPolicy.wrappedValue == policy {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.echoLavender)
                                    .accessibilityLabel("Selected")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, EchoSpacing.xxs)

            Text("Guide text (questions and steps) is always saved locally. Images are stored only according to the policy above.")
                .font(.echoCaption)
                .foregroundStyle(.echoTextTertiary)

        } header: {
            Text("Data")
        }
        .listRowBackground(Color.echoSurface)

        Section {
            Button(role: .destructive) {
                vm.showDeleteAllConfirmation = true
            } label: {
                Label("Delete all guides", systemImage: "trash")
                    .foregroundStyle(.echoDestructive)
            }
            Text("Deletes all saved guide text, steps, and any stored images from this device only.")
                .font(.echoCaption)
                .foregroundStyle(.echoTextTertiary)
        }
        .listRowBackground(Color.echoSurface)
    }

    // MARK: - Permissions section

    private var permissionsSection: some View {
        Section("Permissions") {
            HStack {
                Label("Microphone", systemImage: "mic.fill")
                    .foregroundStyle(.echoTextPrimary)
                Spacer()
                if vm.microphoneStatus == .denied {
                    Button("Open Settings") { vm.openSettings() }
                        .font(.echoFootnote)
                        .foregroundStyle(.echoLavender)
                } else {
                    Text(vm.microphoneStatusLabel)
                        .font(.echoFootnote)
                        .foregroundStyle(.echoTextTertiary)
                }
            }

            HStack {
                Label("Speech Recognition", systemImage: "waveform.and.mic")
                    .foregroundStyle(.echoTextPrimary)
                Spacer()
                if vm.speechStatus == .denied {
                    Button("Open Settings") { vm.openSettings() }
                        .font(.echoFootnote)
                        .foregroundStyle(.echoLavender)
                } else {
                    Text(vm.speechStatusLabel)
                        .font(.echoFootnote)
                        .foregroundStyle(.echoTextTertiary)
                }
            }

            HStack(alignment: .top, spacing: EchoSpacing.sm) {
                Label("Photos", systemImage: "photo")
                    .foregroundStyle(.echoTextPrimary)
                Spacer()
                Text("System picker — no broad access needed")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .listRowBackground(Color.echoSurface)
    }

    // MARK: - About section

    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                PrivacyInfoView()
            } label: {
                Label("How Echo protects your privacy", systemImage: "lock.shield")
                    .foregroundStyle(.echoTextPrimary)
            }

            Button {
            } label: {
                Label("Terms of Use", systemImage: "doc.text")
                    .foregroundStyle(.echoTextPrimary)
            }

            Button {
            } label: {
                Label("Privacy Policy", systemImage: "hand.raised")
                    .foregroundStyle(.echoTextPrimary)
            }

            HStack {
                Label("Version", systemImage: "info.circle")
                    .foregroundStyle(.echoTextPrimary)
                Spacer()
                Text(vm.appVersion)
                    .font(.echoFootnote)
                    .foregroundStyle(.echoTextTertiary)
            }
        }
        .listRowBackground(Color.echoSurface)
    }
}

// MARK: - Privacy info detail view

private struct PrivacyInfoView: View {
    private let points: [(icon: String, title: String, detail: String)] = [
        ("hand.raised.fill",  "You control what Echo sees",       "Echo never accesses your screen, camera, or microphone without a direct action from you."),
        ("mic.slash.fill",    "Voice is always push-to-talk",     "Echo only records when you hold the voice button. Nothing is recorded in the background."),
        ("photo.slash",       "Photos stay on your device",       "Echo uses the system image picker. Images are shared with the analysis service only when you tap 'Create My Guide'."),
        ("trash.fill",        "Delete anytime",                   "Remove any guide — including any saved image — at any time from the guide screen or from 'Delete all guides' in Settings."),
        ("server.rack",       "Provider keys stay on the server", "Your API keys and model-provider credentials are never stored in the app. All analysis is proxied through a server you control.")
    ]

    var body: some View {
        ZStack {
            Color.echoBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: EchoSpacing.md) {
                    ForEach(points, id: \.title) { point in
                        HStack(alignment: .top, spacing: EchoSpacing.md) {
                            Image(systemName: point.icon)
                                .font(.echoTitle3)
                                .foregroundStyle(LinearGradient.echoAccent)
                                .frame(width: 36)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(point.title)
                                    .font(.echoHeadline)
                                    .foregroundStyle(.echoTextPrimary)
                                Text(point.detail)
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
                .padding(EchoSpacing.md)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.echoBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    SettingsView()
        .environment(PetState())
        .modelContainer(for: EchoSession.self, inMemory: true)
}

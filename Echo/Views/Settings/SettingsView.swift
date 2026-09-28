import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var vm = SettingsViewModel()
    @AppStorage("imageRetentionPolicy") private var retentionRaw: String = EchoSession.ImageRetentionPolicy.noSave.rawValue

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
                    dataSection
                    permissionsSection
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

    private var accountSection: some View {
        Section("Account") {
            HStack {
                Label("Echo account", systemImage: "person.circle")
                    .foregroundStyle(.echoTextPrimary)
                Spacer()
                Text("Coming soon")
                    .font(.echoFootnote)
                    .foregroundStyle(.echoTextTertiary)
            }
        }
        .listRowBackground(Color.echoSurface)
    }

    // MARK: - Data section

    private var dataSection: some View {
        Section {
            // Image retention picker
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
            // Microphone
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

            // Speech recognition
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

            // Photos
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
                // Placeholder — link to Terms of Use URL when available
            } label: {
                Label("Terms of Use", systemImage: "doc.text")
                    .foregroundStyle(.echoTextPrimary)
            }

            Button {
                // Placeholder — link to Privacy Policy URL when available
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
        ("hand.raised.fill", "You control what Echo sees", "Echo never accesses your screen, camera, or microphone without a direct action from you."),
        ("mic.slash.fill", "Voice is always push-to-talk", "Echo only records when you hold the voice button. Nothing is recorded in the background."),
        ("photo.slash", "Photos stay on your device", "Echo uses the system image picker. Images are shared with the analysis service only when you tap 'Create My Guide'."),
        ("trash.fill", "Delete anytime", "Remove any guide — including any saved image — at any time from the guide screen or from 'Delete all guides' in Settings."),
        ("server.rack", "Provider keys stay on the server", "Your API keys and model-provider credentials are never stored in the app. All analysis is proxied through a server you control.")
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
        .modelContainer(for: EchoSession.self, inMemory: true)
}

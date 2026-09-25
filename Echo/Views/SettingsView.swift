import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject private var voice: VoiceGuidanceService
    @AppStorage("voiceRate")      private var voiceRate: Double = 0.5
    @AppStorage("voicePitch")     private var voicePitch: Double = 1.0
    @AppStorage("selectedVoiceID") private var selectedVoiceID: String = ""
    @AppStorage("autoSpeak")      private var autoSpeak: Bool = true
    @AppStorage("highlightColor") private var highlightColor: String = "indigo"
    @AppStorage("nlDepthCheck")   private var nlDepthCheck: Bool = true
    @AppStorage("nlA11yCheck")    private var nlA11yCheck: Bool = true
    @AppStorage("nlPatternCheck") private var nlPatternCheck: Bool = true
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            List {
                extensionSection
                voiceSection
                analysisSection
                appearanceSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAbout) { AboutView() }
            .onChange(of: voiceRate)     { _, v in applyVoiceSettings(rate: Float(v)) }
            .onChange(of: voicePitch)    { _, v in applyVoiceSettings(pitch: Float(v)) }
            .onChange(of: selectedVoiceID) { _, id in applyVoiceSettings(voiceID: id) }
        }
    }

    // MARK: - Sections

    private var extensionSection: some View {
        Section {
            HStack {
                Label("Safari Extension", systemImage: "safari")
                Spacer()
                Text("Enable in Safari Settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label("App Group ID", systemImage: "key")
                Spacer()
                Text("group.com.echo.extension")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        } header: {
            Text("Extension")
        } footer: {
            Text("Go to Settings → Safari → Extensions → Echo to enable the web extension.")
        }
    }

    private var voiceSection: some View {
        Section("Voice Guidance") {
            Toggle("Auto-speak on inspection", isOn: $autoSpeak)
                .tint(.indigo)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Speech Rate", systemImage: "speedometer")
                    Spacer()
                    Text(String(format: "%.1f×", voiceRate * 2))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $voiceRate, in: 0.2...0.6) {
                    Text("Rate")
                } minimumValueLabel: {
                    Text("Slow").font(.caption2)
                } maximumValueLabel: {
                    Text("Fast").font(.caption2)
                }
                .tint(.indigo)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Pitch", systemImage: "waveform.path")
                    Spacer()
                    Text(String(format: "%.1f", voicePitch))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Slider(value: $voicePitch, in: 0.5...2.0) {
                    Text("Pitch")
                } minimumValueLabel: {
                    Text("Low").font(.caption2)
                } maximumValueLabel: {
                    Text("High").font(.caption2)
                }
                .tint(.indigo)
            }

            if !voice.availableVoices.isEmpty {
                Picker(selection: $selectedVoiceID) {
                    Text("Default").tag("")
                    ForEach(voice.availableVoices, id: \.identifier) { v in
                        Text("\(v.name) (\(v.language))").tag(v.identifier)
                    }
                } label: {
                    Label("Voice", systemImage: "person.wave.2")
                }
            }

            Button {
                voice.speak("Hello! This is how Echo sounds with your current settings.")
            } label: {
                Label("Preview Voice", systemImage: "play.circle")
            }
            .tint(.indigo)
        }
    }

    private var analysisSection: some View {
        Section("On-Device Analysis") {
            Toggle("Accessibility checks", isOn: $nlA11yCheck)
                .tint(.indigo)
            Toggle("Pattern detection", isOn: $nlPatternCheck)
                .tint(.indigo)
            Toggle("DOM depth warnings", isOn: $nlDepthCheck)
                .tint(.indigo)

            HStack {
                Label("NL Framework", systemImage: "brain")
                Spacer()
                Text("On-device")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(.green)
            }
        }
    }

    private var appearanceSection: some View {
        Section("Inspector Overlay") {
            Picker(selection: $highlightColor) {
                Text("Indigo").tag("indigo")
                Text("Blue").tag("blue")
                Text("Green").tag("green")
                Text("Orange").tag("orange")
                Text("Red").tag("red")
            } label: {
                Label("Highlight Color", systemImage: "paintpalette")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                showingAbout = true
            } label: {
                Label("About Echo", systemImage: "info.circle")
                    .foregroundStyle(.primary)
            }

            LabeledContent("Version", value: "1.0")
            LabeledContent("Build", value: "1")
        } header: {
            Text("About")
        }
    }

    private func applyVoiceSettings(rate: Float? = nil, pitch: Float? = nil, voiceID: String? = nil) {
        voice.configure(
            rate: rate ?? Float(voiceRate),
            pitch: pitch ?? Float(voicePitch),
            voiceIdentifier: voiceID ?? selectedVoiceID
        )
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 90, height: 90)
                            Text("◈")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                        }
                        Text("Echo")
                            .font(.largeTitle.bold())
                        Text("Web Inspector + Voice Guide")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "viewfinder.circle.fill", color: .indigo,
                                   title: "Visual Element Inspector",
                                   description: "Click any element on a webpage to extract its HTML, CSS, attributes, and XPath.")
                        FeatureRow(icon: "brain", color: .purple,
                                   title: "On-Device Intelligence",
                                   description: "Natural Language framework analyzes elements locally for accessibility, patterns, and naming conventions.")
                        FeatureRow(icon: "waveform.circle.fill", color: .blue,
                                   title: "Voice-Driven Guidance",
                                   description: "Speak commands and Echo reads analysis aloud using SiriKit-compatible speech recognition.")
                        FeatureRow(icon: "safari", color: .teal,
                                   title: "Safari Extension",
                                   description: "Injects a non-intrusive inspector overlay into any web page on iOS and macOS.")
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

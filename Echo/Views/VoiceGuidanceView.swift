import SwiftUI
import SwiftData
import AVFoundation

struct VoiceGuidanceView: View {
    @EnvironmentObject private var voice: VoiceGuidanceService
    @EnvironmentObject private var bridge: ExtensionBridgeService
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMode: GuidanceMode = .debug
    @State private var customPrompt: String = ""
    @FocusState private var promptFocused: Bool

    enum GuidanceMode: String, CaseIterable {
        case debug        = "Debug"
        case accessibility = "Accessibility"
        case performance  = "Performance"
        case refactor     = "Refactor"

        var icon: String {
            switch self {
            case .debug:         return "wrench.and.screwdriver"
            case .accessibility: return "accessibility"
            case .performance:   return "bolt.circle"
            case .refactor:      return "arrow.triangle.2.circlepath"
            }
        }

        var startPrompt: String {
            switch self {
            case .debug:
                return "I'm ready to help you debug. Open Safari, enable the Echo extension, then click any element on the page to begin inspection."
            case .accessibility:
                return "Accessibility audit mode activated. I'll guide you through checking your page for WCAG compliance issues. Start by selecting a navigation or form element."
            case .performance:
                return "Performance mode active. I'll identify render-blocking elements, heavy DOM nesting, and resource-heavy patterns. Select an element to begin."
            case .refactor:
                return "Refactor mode ready. I'll suggest cleaner markup, better semantic HTML, and naming convention improvements as you inspect elements."
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    modeSelector
                    microphoneSection
                    transcriptSection
                    responseSection
                    quickCommands
                }
                .padding()
            }
            .navigationTitle("Voice Guide")
            .task {
                if voice.permissionStatus == .unknown {
                    await voice.requestPermissions()
                }
            }
            .onChange(of: bridge.pendingVoiceCommand) { _, cmd in
                guard let cmd else { return }
                handleVoiceIntent(voice.detectIntent(from: cmd), raw: cmd)
                bridge.pendingVoiceCommand = nil
            }
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Guidance Mode")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(GuidanceMode.allCases, id: \.self) { mode in
                    ModeCard(mode: mode, isSelected: selectedMode == mode) {
                        selectedMode = mode
                    }
                }
            }
        }
    }

    // MARK: - Microphone Section

    private var microphoneSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer pulse rings when listening
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(.indigo.opacity(voice.isListening ? 0.2 - Double(i) * 0.06 : 0), lineWidth: 1)
                        .scaleEffect(voice.isListening ? 1.0 + CGFloat(i + 1) * 0.25 + CGFloat(voice.audioLevel) * 0.3 : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever().delay(Double(i) * 0.15), value: voice.isListening)
                }

                // Waveform bars
                if voice.isListening {
                    WaveformView(level: voice.audioLevel)
                        .frame(width: 100, height: 100)
                }

                // Main mic button
                Button {
                    toggleListening()
                } label: {
                    ZStack {
                        Circle()
                            .fill(voice.isListening
                                  ? LinearGradient(colors: [.red, .pink], startPoint: .top, endPoint: .bottom)
                                  : LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                            .frame(width: 80, height: 80)
                            .shadow(color: voice.isListening ? .red.opacity(0.4) : .indigo.opacity(0.4), radius: 16)

                        Image(systemName: voice.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(voice.permissionStatus == .denied)
            }
            .frame(height: 140)

            Text(voice.isListening ? "Listening..." : "Tap to speak a command")
                .font(.subheadline)
                .foregroundStyle(voice.isListening ? .indigo : .secondary)
                .animation(.easeInOut, value: voice.isListening)

            // Start/stop guidance button
            Button {
                voice.speak(selectedMode.startPrompt)
            } label: {
                Label("Start \(selectedMode.rawValue) Guidance", systemImage: selectedMode.icon)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("You said", systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if voice.transcript.isEmpty {
                Text("Your voice commands will appear here")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(voice.transcript)
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Response

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Echo", systemImage: "waveform.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.indigo)
                Spacer()
                if voice.isSpeaking {
                    HStack(spacing: 3) {
                        ForEach(0..<4) { i in
                            Capsule()
                                .fill(.indigo)
                                .frame(width: 3, height: CGFloat.random(in: 6...16))
                                .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.1), value: voice.isSpeaking)
                        }
                    }
                }
            }

            if voice.lastResponse.isEmpty {
                Text("Tap 'Start Guidance' to begin")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(voice.lastResponse)
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.indigo.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.indigo.opacity(0.2), lineWidth: 1))
        )
    }

    // MARK: - Quick Commands

    private var quickCommands: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Commands")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            let commands: [(String, String, VoiceGuidanceService.VoiceIntent)] = [
                ("Analyze Element", "viewfinder.circle", .analyze),
                ("Find Suggestions", "lightbulb", .suggest),
                ("Explain This", "questionmark.circle", .explain),
                ("Fix Issues", "wrench", .fix),
            ]

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(commands, id: \.0) { title, icon, intent in
                    Button {
                        handleVoiceIntent(intent, raw: title)
                    } label: {
                        Label(title, systemImage: icon)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleListening() {
        if voice.isListening {
            voice.stopListening()
        } else {
            voice.onIntentDetected = { intent, raw in
                handleVoiceIntent(intent, raw: raw)
                saveCommandRecord(transcript: raw, intent: intent.label)
            }
            voice.startListening()
        }
    }

    private func handleVoiceIntent(_ intent: VoiceGuidanceService.VoiceIntent, raw: String) {
        guard let snap = bridge.lastSnapshot else {
            voice.speak("No element is currently selected. Please open Safari, enable Echo, and click an element first.")
            return
        }

        let response: String
        switch intent {
        case .analyze:
            response = NLAnalysisService.shared.voiceSummary(for: snap)
        case .suggest:
            if snap.aiSuggestions.isEmpty {
                response = "No suggestions found for this element. It looks clean!"
            } else {
                response = "Here are my suggestions. " + snap.aiSuggestions.prefix(3).joined(separator: ". ")
            }
        case .explain:
            response = "This is a \(snap.tagName.lowercased()) element, classified as \(snap.aiClassification). \(snap.innerText.isEmpty ? "It contains no visible text." : "Its content reads: \(snap.innerText.prefix(100)).")"
        case .fix:
            if snap.aiSuggestions.isEmpty {
                response = "No issues found. This element looks good!"
            } else {
                response = "To fix this element: \(snap.aiSuggestions[0])"
            }
        case .describe:
            response = NLAnalysisService.shared.voiceSummary(for: snap)
        case .inspect, .navigate, .unknown:
            response = "I heard: \(raw). Try saying 'analyze', 'suggest', 'explain', or 'fix'."
        }

        voice.speak(response)
    }

    private func saveCommandRecord(transcript: String, intent: String) {
        let record = VoiceCommandRecord(transcript: transcript, detectedIntent: intent, wasSuccessful: true)
        modelContext.insert(record)
    }
}

// MARK: - Mode Card

struct ModeCard: View {
    let mode: VoiceGuidanceView.GuidanceMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: mode.icon)
                    .font(.callout)
                Text(mode.rawValue)
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? .indigo : Color(.secondarySystemGroupedBackground))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let level: Float
    private let barCount = 20

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .bottom, endPoint: .top))
                    .frame(width: 3, height: barHeight(for: i))
                    .animation(.easeInOut(duration: 0.15), value: level)
            }
        }
        .opacity(0.6)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let center = barCount / 2
        let distance = abs(index - center)
        let base = max(4, CGFloat(level) * 80 * (1 - Double(distance) / Double(center + 1)))
        return base + CGFloat.random(in: 0...4)
    }
}

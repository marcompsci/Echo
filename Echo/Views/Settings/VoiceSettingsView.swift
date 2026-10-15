import SwiftUI
import AVFoundation

// MARK: - Voice & Simple Mode

struct VoiceSettingsView: View {
    @AppStorage(EchoVoicePrefs.voiceKey) private var voiceID = ""
    @AppStorage(EchoVoicePrefs.rateKey) private var rate = 1.0
    @AppStorage(EchoVoicePrefs.simpleModeKey) private var simpleMode = false
    @AppStorage(EchoVoicePrefs.keepListeningKey) private var keepListening = false
    @State private var narrator = GuideNarrator()
    private let voices = EchoVoicePrefs.availableVoices()

    var body: some View {
        List {
            Section {
                Toggle(isOn: $simpleMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Simple Mode")
                        Text("Plain words, slower voice, bigger text, and steps that say exactly where to tap. Great for anyone new to iPhone.")
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextTertiary)
                    }
                }
                .tint(.echoLavender)
                Toggle(isOn: $keepListening) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conversation mode")
                        Text("After Echo answers, it keeps listening so you can ask a follow-up without tapping.")
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextTertiary)
                    }
                }
                .tint(.echoLavender)
            }
            .listRowBackground(Color.echoSurface)

            Section {
                Picker("Voice", selection: $voiceID) {
                    Text("Best available").tag("")
                    ForEach(voices, id: \.identifier) { voice in
                        Text("\(voice.name)\(qualityLabel(voice))").tag(voice.identifier)
                    }
                }
                VStack(alignment: .leading) {
                    Text("Speaking speed")
                    Slider(value: $rate, in: 0.7...1.3, step: 0.05) {
                        Text("Speaking speed")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise")
                    } maximumValueLabel: {
                        Image(systemName: "hare")
                    }
                    .tint(.echoLavender)
                }
                Button {
                    narrator.speak(text: UserProfile.helpGreeting)
                } label: {
                    Label("Hear Echo", systemImage: "speaker.wave.2.fill")
                        .foregroundStyle(.echoLavender)
                }
            } header: {
                Text("Echo's voice")
            } footer: {
                Text("Get nicer voices in iPhone Settings → Accessibility → Spoken Content → Voices. Download an Enhanced or Premium voice and pick it here.")
            }
            .listRowBackground(Color.echoSurface)
        }
        .scrollContentBackground(.hidden)
        .background(Color.echoBackground)
        .navigationTitle("Voice & Simple Mode")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { narrator.stop() }
    }

    private func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return " (Premium)"
        case .enhanced: return " (Enhanced)"
        default: return ""
        }
    }
}

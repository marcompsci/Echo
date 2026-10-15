import Foundation
import AVFoundation

// MARK: - Guide narrator (Echo talks back, like Clicky)
//
// Reads the summary and each step aloud with the system voice and reports
// which step is being spoken, so the Result screen can move Echo's pointer
// to that step's marker in sync with the voice.

@Observable
@MainActor
final class GuideNarrator: NSObject {

    static let autoSpeakKey = "speakGuidesAloud"

    private(set) var isSpeaking = false
    /// nil while the summary/safety notice is spoken; 0-based step index otherwise.
    private(set) var currentStepIndex: Int? = nil

    private let synthesizer = AVSpeechSynthesizer()
    private var stepForUtterance: [ObjectIdentifier: Int?] = [:]
    private var lastUtterance: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ response: GuideResponse) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        var parts: [(Int?, String)] = [(nil, response.summary)]
        if let notice = response.safetyNotice, !notice.isEmpty {
            parts.append((nil, "Heads up. \(notice)"))
        }
        for (index, step) in response.steps.enumerated() {
            parts.append((index, "Step \(step.number). \(step.title). \(step.detail)"))
        }

        let voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        for (index, text) in parts {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
            utterance.postUtteranceDelay = 0.35
            let id = ObjectIdentifier(utterance)
            stepForUtterance[id] = .some(index)
            lastUtterance = id
            synthesizer.speak(utterance)
        }
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        stepForUtterance.removeAll()
        lastUtterance = nil
        isSpeaking = false
        currentStepIndex = nil
        EchoVoiceActivity.shared.setMode(.idle)
    }

    /// Speaks any text (used by Hey Echo answers).
    func speak(text: String) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.97
        let id = ObjectIdentifier(utterance)
        stepForUtterance[id] = .some(nil)
        lastUtterance = id
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    fileprivate func didStart(_ id: ObjectIdentifier) {
        EchoVoiceActivity.shared.setMode(.speaking)
        guard let entry = stepForUtterance[id] else { return }
        currentStepIndex = entry
    }

    fileprivate func didFinish(_ id: ObjectIdentifier) {
        guard id == lastUtterance else { return }
        isSpeaking = false
        EchoVoiceActivity.shared.setMode(.idle)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension GuideNarrator: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.didStart(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        EchoVoiceActivity.shared.wordSpoken()
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.didFinish(id) }
    }
}

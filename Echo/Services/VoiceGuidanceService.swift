import Foundation
import AVFoundation
import Speech
import Combine

final class VoiceGuidanceService: NSObject, ObservableObject {
    static let shared = VoiceGuidanceService()

    // MARK: - Published State

    @Published var isListening: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var transcript: String = ""
    @Published var lastResponse: String = ""
    @Published var audioLevel: Float = 0
    @Published var permissionStatus: PermissionStatus = .unknown

    enum PermissionStatus { case unknown, granted, denied }

    // MARK: - Intent

    enum VoiceIntent {
        case inspect, analyze, suggest, fix, explain, describe, navigate, unknown(String)
        var label: String {
            switch self {
            case .inspect:          return "Inspect Element"
            case .analyze:          return "Analyze"
            case .suggest:          return "Get Suggestions"
            case .fix:              return "Fix Issues"
            case .explain:          return "Explain"
            case .describe:         return "Describe"
            case .navigate:         return "Navigate"
            case .unknown(let raw): return raw
            }
        }
    }

    var onIntentDetected: ((VoiceIntent, String) -> Void)?

    // MARK: - Private

    private let synthesizer = AVSpeechSynthesizer()
    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    private var voiceRate: Float = 0.5
    private var voicePitch: Float = 1.0
    private var voiceIdentifier: String = ""

    private override init() {
        super.init()
        synthesizer.delegate = self
        recognizer = SFSpeechRecognizer(locale: .current)
        setupAudioSession()
    }

    private func setupAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default,
                                                          options: [.defaultToSpeaker, .allowBluetoothHFP])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    // MARK: - Permissions

    func requestPermissions() async {
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }

        let micGranted: Bool
        #if os(iOS)
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
        #else
        micGranted = true  // macOS uses a different permission flow (Info.plist key triggers system dialog)
        #endif

        await MainActor.run {
            permissionStatus = (speechStatus == .authorized && micGranted) ? .granted : .denied
        }
    }

    // MARK: - Text-to-Speech

    func speak(_ text: String, rate: Float? = nil, pitch: Float? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate ?? voiceRate
        utterance.pitchMultiplier = pitch ?? voicePitch
        if !voiceIdentifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        }
        DispatchQueue.main.async { self.lastResponse = text }
        synthesizer.speak(utterance)
    }

    func stopSpeaking() { synthesizer.stopSpeaking(at: .immediate) }

    // MARK: - Speech Recognition

    func startListening() {
        guard permissionStatus == .granted, !isListening else { return }
        stopListeningCleanup()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.updateAudioLevel(buffer: buffer)
        }

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { self.transcript = text }
                self.resetSilenceTimer(text: text)
            }
            if error != nil || result?.isFinal == true { self.stopListeningCleanup() }
        }

        audioEngine.prepare()
        try? audioEngine.start()
        DispatchQueue.main.async { self.isListening = true }
    }

    func stopListening() { stopListeningCleanup() }

    private func stopListeningCleanup() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        DispatchQueue.main.async { self.isListening = false; self.audioLevel = 0 }
    }

    private func resetSilenceTimer(text: String) {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.stopListeningCleanup()
            let intent = self.detectIntent(from: text)
            DispatchQueue.main.async { self.onIntentDetected?(intent, text) }
        }
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames { sum += abs(data[0][i]) }
        let avg = frames > 0 ? sum / Float(frames) : 0
        DispatchQueue.main.async { self.audioLevel = min(avg * 40, 1.0) }
    }

    // MARK: - Intent Detection

    func detectIntent(from text: String) -> VoiceIntent {
        let lower = text.lowercased()
        if lower.contains("inspect") || lower.contains("select") || lower.contains("pick")  { return .inspect }
        if lower.contains("analy")  || lower.contains("examine") || lower.contains("check") { return .analyze }
        if lower.contains("suggest") || lower.contains("improve") || lower.contains("better") { return .suggest }
        if lower.contains("fix")    || lower.contains("repair")  || lower.contains("solve")  { return .fix }
        if lower.contains("explain") || lower.contains("what is") || lower.contains("what does") { return .explain }
        if lower.contains("describe") || lower.contains("tell me") { return .describe }
        if lower.contains("navigate") || lower.contains("go to")  || lower.contains("open")  { return .navigate }
        return .unknown(text)
    }

    // MARK: - Guided Narration

    func narrateStep(_ step: String, index: Int, total: Int) {
        speak("Step \(index) of \(total). \(step)")
    }

    func configure(rate: Float, pitch: Float, voiceIdentifier: String) {
        voiceRate = rate
        voicePitch = pitch
        self.voiceIdentifier = voiceIdentifier
    }

    var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceGuidanceService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = true }
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { self.isSpeaking = false }
    }
}

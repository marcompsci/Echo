import Foundation
import Speech
import AVFoundation

// MARK: - Hands-free listening for "Hey Echo"
//
// Starts listening right away (no holding a button), shows words as you say
// them, and stops on its own after you pause — like Siri.

@Observable
@MainActor
final class HeyEchoListener {
    private(set) var transcript = ""
    private(set) var isListening = false

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTask: Task<Void, Never>?
    private var continuation: CheckedContinuation<String, Never>?

    /// Listens until a pause, then returns what was said ("" if nothing).
    func listen(silenceTimeout: Double = 1.6, maxDuration: Double = 15) async -> String {
        guard await Self.requestPermissions(),
              let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable else {
            return ""
        }
        transcript = ""
        return await withCheckedContinuation { cont in
            continuation = cont
            do {
                try start(recognizer: recognizer, silenceTimeout: silenceTimeout, maxDuration: maxDuration)
            } catch {
                finish()
            }
        }
    }

    func stop() { finish() }

    // MARK: - Internals

    private func start(recognizer: SFSpeechRecognizer, silenceTimeout: Double, maxDuration: Double) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request

        let engine = AVAudioEngine()
        SpeechTaps.install(on: engine.inputNode, feeding: request)
        engine.prepare()
        try engine.start()
        self.engine = engine
        isListening = true
        EchoVoiceActivity.shared.setMode(.listening)

        task = SpeechTaps.recognize(with: recognizer, request: request) { [weak self] text, isFinal, error in
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text; self.restartSilenceTimer(silenceTimeout) }
                if isFinal || error != nil { self.finish() }
            }
        }

        // Give up if nobody speaks; hard cap on length.
        restartSilenceTimer(silenceTimeout + 3)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(maxDuration))
            self?.finish()
        }
    }

    private func restartSilenceTimer(_ seconds: Double) {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        guard isListening || continuation != nil else { return }
        silenceTask?.cancel()
        if let engine { SpeechTaps.stop(engine: engine) }
        request?.endAudio()
        task?.cancel()
        engine = nil; request = nil; task = nil
        isListening = false
        EchoVoiceActivity.shared.setMode(.idle)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        let cont = continuation
        continuation = nil
        cont?.resume(returning: transcript.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

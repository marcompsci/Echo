import Foundation
import Speech
import AVFoundation
import os

// MARK: - Protocol

protocol SpeechServiceProtocol: Sendable {
    func requestPermissions() async -> Bool
    func transcribeFromMicrophone() async throws -> String
    /// Stop listening and deliver what was heard (release of "hold to speak").
    func finishTranscription()
    func cancelTranscription()
}

extension SpeechServiceProtocol {
    func finishTranscription() { cancelTranscription() }
}

// MARK: - Mock (default in MVP)

struct MockSpeechService: SpeechServiceProtocol {
    func requestPermissions() async -> Bool { true }

    func transcribeFromMicrophone() async throws -> String {
        try await Task.sleep(for: .seconds(1.5))
        return "What do I tap next?"
    }

    func cancelTranscription() {}
}

// MARK: - Live implementation

final class LiveSpeechService: SpeechServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    func requestPermissions() async -> Bool {
        let speechGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else { return false }
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    func transcribeFromMicrophone() async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: .current),
              recognizer.isAvailable else {
            throw EchoError.analysisUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true   // private: audio stays on the iPhone
        }
        lock.lock(); recognitionRequest = request; lock.unlock()

        let engine = AVAudioEngine()
        lock.lock(); audioEngine = engine; lock.unlock()

        SpeechTaps.install(on: engine.inputNode, feeding: request)
        EchoVoiceActivity.shared.setMode(.listening)
        try engine.start()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                let resumed = OSAllocatedUnfairLock(initialState: false)
                let task = SpeechTaps.recognize(with: recognizer, request: request) { text, isFinal, error in
                    let first = resumed.withLock { done -> Bool in
                        if done { return false }
                        if isFinal || error != nil { done = true; return true }
                        return false
                    }
                    guard first else { return }
                    SpeechTaps.stop(engine: engine)
                    EchoVoiceActivity.shared.setMode(.idle)
                    try? AVAudioSession.sharedInstance().setActive(false)
                    if isFinal, let text {
                        cont.resume(returning: text)
                    } else {
                        cont.resume(throwing: error ?? CancellationError())
                    }
                }
                self.lock.lock(); self.recognitionTask = task; self.lock.unlock()
            }
        } onCancel: {
            self.cancelTranscription()
        }
    }

    /// Ends the audio stream so the recognizer returns its final transcript.
    func finishTranscription() {
        lock.lock()
        let request = recognitionRequest
        let engine = audioEngine
        recognitionRequest = nil
        audioEngine = nil
        lock.unlock()
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
    }

    func cancelTranscription() {
        lock.lock()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        let engine = audioEngine
        audioEngine = nil
        lock.unlock()
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func cleanup(engine: AVAudioEngine, session: AVAudioSession) {
        EchoVoiceActivity.shared.setMode(.idle)
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? session.setActive(false)
    }
}

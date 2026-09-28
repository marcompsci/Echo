import Foundation
import Speech
import AVFoundation

// MARK: - Protocol

protocol SpeechServiceProtocol: Sendable {
    func requestPermissions() async -> Bool
    func transcribeFromMicrophone() async throws -> String
    func cancelTranscription()
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

        let engine = AVAudioEngine()
        lock.lock(); audioEngine = engine; lock.unlock()

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        try engine.start()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        self.cleanup(engine: engine, session: audioSession)
                        cont.resume(returning: result.bestTranscription.formattedString)
                    } else if let error {
                        self.cleanup(engine: engine, session: audioSession)
                        cont.resume(throwing: error)
                    }
                }
                self.lock.lock(); self.recognitionTask = task; self.lock.unlock()
            }
        } onCancel: {
            self.cancelTranscription()
        }
    }

    func cancelTranscription() {
        lock.lock()
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
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? session.setActive(false)
    }
}

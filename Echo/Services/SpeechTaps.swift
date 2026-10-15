import Foundation
import Speech
import AVFoundation

// MARK: - Audio callbacks that run off the main thread
//
// This app target defaults to @MainActor. Closures written inside main-actor
// code inherit that isolation and crash when AVAudioEngine / Speech call them
// on their own threads. Creating them in these nonisolated helpers avoids that.

nonisolated enum SpeechTaps {

    /// Feeds mic audio to the recognizer and the orb's level meter.
    static func install(on input: AVAudioInputNode, feeding request: SFSpeechAudioBufferRecognitionRequest) {
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
            EchoVoiceActivity.shared.reportMicLevel(level(of: buffer))
        }
    }

    /// Starts recognition; `handler` gets (text, isFinal, error) on a background thread.
    static func recognize(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        handler: @escaping @Sendable (String?, Bool, Error?) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            handler(result?.bestTranscription.formattedString, result?.isFinal ?? false, error)
        }
    }

    static func stop(engine: AVAudioEngine) {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Rough 0–1 loudness of a mic buffer.
    static func level(of buffer: AVAudioPCMBuffer) -> Double {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        let n = Int(buffer.frameLength)
        for i in 0..<n { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(n))
        let db = 20 * log10(max(rms, 0.000_01))
        return Double(max(0, min(1, (db + 50) / 40)))
    }
}

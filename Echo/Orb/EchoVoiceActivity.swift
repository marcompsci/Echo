import Foundation
import os

// MARK: - Echo's voice activity (drives the orb's shape)
//
// Anything that speaks (GuideNarrator, Hey Echo) or listens (speech
// recognition) reports here. The orb reads `energy(at:)` every frame.
// Thread-safe: the mic tap reports from the audio thread.

nonisolated final class EchoVoiceActivity: @unchecked Sendable {
    static let shared = EchoVoiceActivity()

    enum Mode: Sendable { case idle, listening, thinking, speaking }

    private struct State {
        var mode: Mode = .idle
        var pulse: Double = 0          // last word / loudness spike (0–1)
        var pulseTime: TimeInterval = 0
        var micLevel: Double = 0
    }
    private let state = OSAllocatedUnfairLock(initialState: State())

    var mode: Mode { state.withLock { $0.mode } }

    func setMode(_ mode: Mode) {
        state.withLock { $0.mode = mode }
    }

    /// Called on each spoken word — gives the orb a "syllable" bump.
    func wordSpoken() {
        let now = Date().timeIntervalSinceReferenceDate
        state.withLock {
            $0.pulse = Double.random(in: 0.55...1.0)
            $0.pulseTime = now
        }
    }

    /// Microphone loudness, 0–1 (from the audio tap).
    func reportMicLevel(_ level: Double) {
        let now = Date().timeIntervalSinceReferenceDate
        let clamped = max(0, min(1, level))
        state.withLock {
            $0.micLevel = $0.micLevel * 0.6 + clamped * 0.4
            if clamped > $0.pulse * 0.8 { $0.pulse = clamped; $0.pulseTime = now }
        }
    }

    /// 0 (calm) … 1 (very animated) for the given moment.
    func energy(at date: Date) -> (mode: Mode, energy: Double) {
        let now = date.timeIntervalSinceReferenceDate
        return state.withLock { s in
            let decay = exp(-(now - s.pulseTime) * 5.5)
            switch s.mode {
            case .idle:      return (.idle, 0)
            case .thinking:  return (.thinking, 0.25)
            case .listening: return (.listening, min(1, 0.15 + s.micLevel * 0.9 + s.pulse * decay * 0.4))
            case .speaking:  return (.speaking, min(1, 0.3 + s.pulse * decay * 0.7))
            }
        }
    }
}

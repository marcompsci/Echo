import Foundation
import UserNotifications
import AVFoundation

// MARK: - Shows and speaks each step while the person is in another app
//
// iOS doesn't let Echo draw over other apps, so guidance arrives as a
// notification banner (visible over any app) plus Echo's voice.

final class LiveGuideNotifier {
    private let center = UNUserNotificationCenter.current()
    private let synthesizer = AVSpeechSynthesizer()
    private var lastID: String?
    private let speakAloud: Bool

    init(speakAloud: Bool) {
        self.speakAloud = speakAloud
        if speakAloud {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers, .duckOthers])
        }
    }

    func show(title: String, body: String, speak spoken: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = speakAloud ? nil : .default
        content.threadIdentifier = "echo-live-guide"
        content.interruptionLevel = .active

        // Replace the previous banner so Notification Center keeps one current step.
        if let lastID { center.removeDeliveredNotifications(withIdentifiers: [lastID]) }
        let id = UUID().uuidString
        lastID = id
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))

        if speakAloud, let spoken {
            try? AVAudioSession.sharedInstance().setActive(true)
            if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
            let utterance = AVSpeechUtterance(string: spoken)
            utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
            synthesizer.speak(utterance)
        }
    }

    func clear() {
        if let lastID { center.removeDeliveredNotifications(withIdentifiers: [lastID]) }
        synthesizer.stopSpeaking(at: .immediate)
    }
}

import Foundation
import AVFoundation
import Speech

@Observable
@MainActor
final class SettingsViewModel {
    var imageRetentionPolicy: EchoSession.ImageRetentionPolicy = .noSave
    var microphoneStatus: AVAudioApplication.recordPermission = .undetermined
    var speechStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    var showDeleteAllConfirmation = false
    var errorMessage: String? = nil
    var successMessage: String? = nil

    init() {
        refresh()
    }

    func refresh() {
        microphoneStatus = AVAudioApplication.shared.recordPermission
        speechStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func deleteAllGuides(store: SessionStore) {
        do {
            try store.deleteAll()
            successMessage = "All guides have been deleted."
        } catch {
            errorMessage = "Could not delete guides. Please try again."
        }
    }

    var microphoneStatusLabel: String {
        switch microphoneStatus {
        case .granted:      return "Allowed"
        case .denied:       return "Denied — tap to open Settings"
        case .undetermined: return "Not yet requested"
        @unknown default:   return "Unknown"
        }
    }

    var speechStatusLabel: String {
        switch speechStatus {
        case .authorized:        return "Allowed"
        case .denied:            return "Denied — tap to open Settings"
        case .restricted:        return "Restricted by device policy"
        case .notDetermined:     return "Not yet requested"
        @unknown default:        return "Unknown"
        }
    }

    var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

// Import UIKit here to avoid polluting other files
import UIKit

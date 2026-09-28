import Foundation

enum EchoError: LocalizedError, Sendable {
    case imageProcessingFailed
    case analysisUnavailable
    case networkUnavailable
    case sessionNotFound
    case permissionDenied(PermissionType)
    case invalidResponse
    case unknown(String)

    enum PermissionType: Sendable {
        case microphone
        case speechRecognition
        case photoLibrary
        case contacts
        case reminders
        case calendar
    }

    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Echo couldn't process that image. Try a different screenshot or photo."
        case .analysisUnavailable:
            return "Echo's guide service is currently unavailable. Please try again."
        case .networkUnavailable:
            return "Check your connection and try again."
        case .sessionNotFound:
            return "That guide no longer exists."
        case .permissionDenied(let type):
            switch type {
            case .microphone:
                return "Microphone access is needed for voice questions. Enable it in Settings."
            case .speechRecognition:
                return "Speech recognition is needed for voice questions. Enable it in Settings."
            case .photoLibrary:
                return "Use the system picker to import photos — no broad library access needed."
            case .contacts:
                return "Contacts access was denied. Enable it in Settings → Privacy → Contacts."
            case .reminders:
                return "Reminders access was denied. Enable it in Settings → Privacy → Reminders."
            case .calendar:
                return "Calendar access was denied. Enable it in Settings → Privacy → Calendars."
            }
        case .invalidResponse:
            return "Echo received an unexpected response. Please try again."
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Open Settings → Privacy to enable access."
        case .networkUnavailable:
            return "Check your Wi-Fi or cellular connection."
        default:
            return "Try again in a moment."
        }
    }
}

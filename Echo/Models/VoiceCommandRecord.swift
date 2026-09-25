import Foundation
import SwiftData

@Model
final class VoiceCommandRecord {
    var id: UUID
    var timestamp: Date
    var transcript: String
    var detectedIntent: String
    var response: String
    var wasSuccessful: Bool

    init(transcript: String, detectedIntent: String = "", response: String = "", wasSuccessful: Bool = false) {
        self.id = UUID()
        self.timestamp = Date()
        self.transcript = transcript
        self.detectedIntent = detectedIntent
        self.response = response
        self.wasSuccessful = wasSuccessful
    }
}

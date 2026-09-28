import Foundation
import SwiftData

@Model
final class EchoSession {
    var id: UUID
    var question: String
    var summary: String
    var safetyNotice: String?
    var createdAt: Date
    // Image stored only when user's retention policy allows it
    var imageData: Data?
    // Encoded GuideResponse for offline viewing
    var guideResponseData: Data?
    var imageRetentionPolicy: String  // raw value of ImageRetentionPolicy

    static let schemaVersion = 1

    enum ImageRetentionPolicy: String, CaseIterable {
        case noSave          = "no_save"
        case deleteAfter24h  = "delete_after_24h"
        case keepUntilDeleted = "keep_until_deleted"

        var label: String {
            switch self {
            case .noSave:          return "Don't save images"
            case .deleteAfter24h:  return "Delete images after 24 hours"
            case .keepUntilDeleted: return "Keep until I delete"
            }
        }

        var detail: String {
            switch self {
            case .noSave:
                return "Images are never written to disk. Guide text and steps are saved."
            case .deleteAfter24h:
                return "Images are deleted automatically after 24 hours. Guide text is kept."
            case .keepUntilDeleted:
                return "Images stay until you delete the guide. You can remove any guide at any time."
            }
        }
    }

    var retentionPolicy: ImageRetentionPolicy {
        get { ImageRetentionPolicy(rawValue: imageRetentionPolicy) ?? .noSave }
        set { imageRetentionPolicy = newValue.rawValue }
    }

    var decodedGuideResponse: GuideResponse? {
        guard let data = guideResponseData else { return nil }
        return try? JSONDecoder().decode(GuideResponse.self, from: data)
    }

    var formattedDate: String {
        createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var questionPreview: String {
        question.count > 60 ? String(question.prefix(60)) + "…" : question
    }

    init(
        id: UUID = UUID(),
        question: String,
        summary: String,
        safetyNotice: String? = nil,
        createdAt: Date = .now,
        imageData: Data? = nil,
        guideResponseData: Data? = nil,
        imageRetentionPolicy: ImageRetentionPolicy = .noSave
    ) {
        self.id = id
        self.question = question
        self.summary = summary
        self.safetyNotice = safetyNotice
        self.createdAt = createdAt
        self.imageData = imageData
        self.guideResponseData = guideResponseData
        self.imageRetentionPolicy = imageRetentionPolicy.rawValue
    }
}

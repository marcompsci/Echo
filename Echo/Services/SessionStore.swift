import Foundation
import SwiftData

// MARK: - Session persistence helper
// Wraps SwiftData operations so ViewModels stay thin.

@MainActor
final class SessionStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // Saves a new guide session. Respects the image retention policy.
    func save(
        question: String,
        response: GuideResponse,
        imageData: Data?,
        retentionPolicy: EchoSession.ImageRetentionPolicy
    ) throws -> EchoSession {
        let storedImage: Data? = switch retentionPolicy {
        case .noSave:          nil
        case .deleteAfter24h:  imageData
        case .keepUntilDeleted: imageData
        }

        let session = EchoSession(
            question: question,
            summary: response.summary,
            safetyNotice: response.safetyNotice,
            imageData: storedImage,
            guideResponseData: response.encodedData,
            imageRetentionPolicy: retentionPolicy
        )
        context.insert(session)
        try context.save()
        return session
    }

    func delete(_ session: EchoSession) throws {
        context.delete(session)
        try context.save()
    }

    func deleteAll() throws {
        let descriptor = FetchDescriptor<EchoSession>()
        let all = try context.fetch(descriptor)
        all.forEach { context.delete($0) }
        try context.save()
    }

    // Purge images older than 24 h that used the deleteAfter24h policy.
    func purgeExpiredImages() throws {
        let cutoff = Date.now.addingTimeInterval(-86400)
        var descriptor = FetchDescriptor<EchoSession>(
            predicate: #Predicate { $0.imageRetentionPolicy == "delete_after_24h" }
        )
        descriptor.propertiesToFetch = [\.id, \.createdAt, \.imageRetentionPolicy]
        let candidates = try context.fetch(descriptor)
        for session in candidates where session.createdAt < cutoff {
            session.imageData = nil
        }
        try context.save()
    }
}

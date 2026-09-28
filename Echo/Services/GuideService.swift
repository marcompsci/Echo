import Foundation

// MARK: - Core AI service protocol

protocol GuideService: Sendable {
    func createGuide(
        imageData: Data,
        userQuestion: String
    ) async throws -> GuideResponse
}

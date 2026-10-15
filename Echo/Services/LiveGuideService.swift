import Foundation

// MARK: - Live guide service — real answers from Claude via the Supabase backend

struct LiveGuideService: GuideService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func createGuide(imageData: Data, userQuestion: String) async throws -> GuideResponse {
        let prepared: PreparedGuideImage
        do {
            prepared = try await Task.detached(priority: .userInitiated) {
                try ScreenTextReader.prepare(imageData)
            }.value
        } catch {
            throw EchoError.imageProcessingFailed
        }

        DevInspector.shared.noteShield(prepared.hidden)
        let request = GuideAPIRequest(prepared: prepared, userQuestion: userQuestion)
        return try await client.createGuide(request: request)
    }
}

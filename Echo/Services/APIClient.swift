import Foundation

// MARK: - API Client scaffold
// No live calls are made in this build.
// See README "Replacing MockGuideService" to activate.

struct APIClient: Sendable {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = URL(string: "https://api.yourdomain.com/v1")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func createGuide(request: GuideAPIRequest) async throws -> GuideResponse {
        let endpoint = baseURL.appendingPathComponent("guides")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Authorization: add server-issued Bearer token here (not a provider key)
        // urlRequest.setValue("Bearer \(serverToken)", forHTTPHeaderField: "Authorization")

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw EchoError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw http.statusCode == 503
                ? EchoError.analysisUnavailable
                : EchoError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(GuideResponse.self, from: data)
        } catch {
            throw EchoError.invalidResponse
        }
    }
}

// MARK: - Request body

struct GuideAPIRequest: Codable, Sendable {
    let imageBase64: String
    let userQuestion: String
    let deviceLocale: String
    let appVersion: String

    init(imageData: Data, userQuestion: String) {
        self.imageBase64 = imageData.base64EncodedString()
        self.userQuestion = userQuestion
        self.deviceLocale = Locale.current.identifier
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Live service (activate by uncommenting + injecting into AnalyzeViewModel)

// struct LiveGuideService: GuideService {
//     private let client: APIClient
//
//     init(client: APIClient = APIClient()) { self.client = client }
//
//     func createGuide(imageData: Data, userQuestion: String) async throws -> GuideResponse {
//         let req = GuideAPIRequest(imageData: imageData, userQuestion: userQuestion)
//         return try await client.createGuide(request: req)
//     }
// }

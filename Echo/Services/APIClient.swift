import Foundation

// MARK: - API client for the Echo guide backend (Supabase Edge Function "echo-guide")
// Provider API keys never live in the app — only the public Supabase anon key.

struct APIClient: Sendable {
    private let endpoint: URL
    private let anonKey: String
    private let session: URLSession

    init(
        endpoint: URL = EchoConfig.guideEndpoint,
        anonKey: String = EchoConfig.supabaseAnonKey,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.anonKey = anonKey
        self.session = session
    }

    func createGuide(request: GuideAPIRequest) async throws -> GuideResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        // Legacy anon keys are JWTs and also go in Authorization.
        // New publishable keys (sb_publishable_…) are not JWTs and must only use "apikey".
        if anonKey.hasPrefix("eyJ") {
            urlRequest.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw EchoError.networkUnavailable
            case .timedOut:
                throw EchoError.analysisUnavailable
            default:
                throw EchoError.networkUnavailable
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw EchoError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            break
        case 413:
            throw EchoError.unknown("That image is too large. Try a regular screenshot.")
        case 429:
            throw EchoError.unknown("Echo is busy right now. Wait a moment and try again.")
        case 401, 403:
            throw EchoError.unknown("Echo couldn't connect to its guide service. Check the Supabase keys in EchoConfig.swift.")
        case 503:
            throw EchoError.analysisUnavailable
        default:
            throw EchoError.invalidResponse
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
    let mediaType: String
    let userQuestion: String
    let deviceLocale: String
    let appVersion: String
    let imageWidth: Int
    let imageHeight: Int
    let elements: [ScreenTextElement]

    init(prepared: PreparedGuideImage, userQuestion: String) {
        self.imageBase64 = prepared.jpegData.base64EncodedString()
        self.mediaType = "image/jpeg"
        self.userQuestion = userQuestion
        self.deviceLocale = Locale.current.identifier
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        self.imageWidth = prepared.pixelWidth
        self.imageHeight = prepared.pixelHeight
        self.elements = prepared.elements
    }
}

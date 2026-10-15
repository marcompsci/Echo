import Foundation

// MARK: - Asks Echo's guide service for the next step toward the goal

struct LiveCoachReply: Decodable {
    enum Status: String, Decodable {
        case nextStep = "next_step"   // here's what to do on this screen
        case done                     // goal reached
        case wrongScreen = "wrong_screen" // not where they need to be; instruction says how to get there
        case waiting                  // screen is loading / nothing to do yet
    }
    let status: Status
    let instruction: String
    let detail: String
    let safetyNotice: String?
}

struct LiveCoachClient {
    let endpoint: URL
    let apiKey: String
    let session: URLSession

    init?(liveSession: LiveGuideSession) {
        guard let url = URL(string: liveSession.endpoint) else { return nil }
        endpoint = url
        apiKey = liveSession.apiKey
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    func nextStep(goal: String, history: [String], jpeg: Data, width: Int, height: Int) async throws -> LiveCoachReply {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        if apiKey.hasPrefix("eyJ") {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "mode": "live",
            "goal": goal,
            "history": Array(history.suffix(8)),
            "userQuestion": goal,
            "imageBase64": jpeg.base64EncodedString(),
            "mediaType": "image/jpeg",
            "imageWidth": width,
            "imageHeight": height,
            "deviceLocale": Locale.current.identifier
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LiveCoachReply.self, from: data)
    }
}

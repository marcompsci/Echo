import Foundation

// MARK: - Talks to the AI you connected (Claude, ChatGPT, Grok, Muse)
//
// Anthropic uses the Messages API; OpenAI, xAI and Meta use the
// OpenAI-style chat-completions format. Screenshots always pass through
// Privacy Shield before they get here.

enum ExternalAIError: LocalizedError {
    case notConnected(AIProvider), badEndpoint, http(Int, String), emptyReply, badJSON

    var errorDescription: String? {
        switch self {
        case .notConnected(let p): return "\(p.name) isn't connected. Add your API key in Settings → Connect AI."
        case .badEndpoint: return "That AI's web address doesn't look right. Check it in Settings → Connect AI."
        case .http(let code, let message):
            switch code {
            case 401, 403: return "The API key was rejected. Check it in Settings → Connect AI."
            case 404: return "That model or address wasn't found. Check the model name in Settings → Connect AI."
            case 429: return "That AI is rate-limiting you or your credit ran out."
            default:  return "The AI returned an error (\(code)). \(message.prefix(140))"
            }
        case .emptyReply: return "The AI didn't send an answer."
        case .badJSON: return "The AI's answer wasn't in the expected format."
        }
    }
}

struct ExternalAIClient {
    let provider: AIProvider
    var session: URLSession = .shared

    func complete(system: String, prompt: String, imageJPEG: Data? = nil, maxTokens: Int = 1200) async throws -> String {
        guard let key = AIConnections.key(for: provider) else { throw ExternalAIError.notConnected(provider) }
        guard let url = URL(string: AIConnections.endpoint(for: provider)) else { throw ExternalAIError.badEndpoint }
        let model = AIConnections.model(for: provider)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any]
        if provider == .claude {
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            var content: [[String: Any]] = []
            if let imageJPEG {
                content.append(["type": "image", "source": ["type": "base64", "media_type": "image/jpeg",
                                                            "data": imageJPEG.base64EncodedString()]])
            }
            content.append(["type": "text", "text": prompt])
            body = ["model": model, "max_tokens": maxTokens, "system": system,
                    "messages": [["role": "user", "content": content]]]
        } else {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            var content: [[String: Any]] = [["type": "text", "text": prompt]]
            if let imageJPEG {
                content.append(["type": "image_url",
                                "image_url": ["url": "data:image/jpeg;base64,\(imageJPEG.base64EncodedString())"]])
            }
            body = ["model": model, (provider == .chatGPT ? "max_completion_tokens" : "max_tokens"): maxTokens,
                    "messages": [["role": "system", "content": system],
                                 ["role": "user", "content": content]]]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(code) else {
            throw ExternalAIError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ExternalAIError.emptyReply }
        let text = Self.text(from: json, anthropic: provider == .claude)
        guard !text.isEmpty else { throw ExternalAIError.emptyReply }
        return text
    }

    /// Asks for JSON and decodes it (tolerates ```json fences and extra prose).
    func completeJSON<T: Decodable>(_ type: T.Type, system: String, prompt: String, imageJPEG: Data? = nil) async throws -> T {
        let text = try await complete(system: system + "\nReply with ONLY a JSON object, no other text.",
                                      prompt: prompt, imageJPEG: imageJPEG)
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"),
              let data = String(text[start...end]).data(using: .utf8) else { throw ExternalAIError.badJSON }
        do { return try JSONDecoder().decode(T.self, from: data) } catch { throw ExternalAIError.badJSON }
    }

    /// A tiny request to confirm the key works.
    func test() async throws -> String {
        try await complete(system: "You are a connection test.", prompt: "Reply with the single word: connected", maxTokens: 20)
    }

    static func text(from json: [String: Any], anthropic: Bool) -> String {
        if anthropic {
            let blocks = json["content"] as? [[String: Any]] ?? []
            return blocks.compactMap { $0["text"] as? String }.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let choices = json["choices"] as? [[String: Any]] ?? []
        let message = choices.first?["message"] as? [String: Any]
        if let s = message?["content"] as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let parts = message?["content"] as? [[String: Any]] {
            return parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }
        return ""
    }
}

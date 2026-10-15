import SwiftUI
import UIKit

// MARK: - Feedback
//
//  • Everyone: tell us what's working or not.
//  • Developers (connected with GitHub): describe a change. Echo rewrites it
//    as a clear change request and commits it to the repo's `echo-feedback`
//    branch, so Omari can pick it up and change the app.

struct FeedbackView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case user = "Feedback", developer = "Developer"
        var id: String { rawValue }
    }

    @State private var accounts = AccountService.shared
    @State private var kind: Kind = .user
    @State private var category = "Idea"
    @State private var area = "General"
    @State private var message = ""
    @State private var isSending = false
    @State private var result: FeedbackClient.Result? = nil
    @State private var errorMessage: String? = nil

    private let categories = ["Idea", "Bug", "Confusing", "Love it", "Other"]
    private let areas = ["General", "Hey Echo", "Live Guide", "Visual Guide", "Echo Agent", "Echo Pet / Orb", "Onboarding", "Settings"]

    var body: some View {
        Form {
            Picker("Type", selection: $kind) {
                ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if kind == .developer && !accounts.isDeveloper {
                Section {
                    Text("Developer feedback goes straight to GitHub, so connect your GitHub account first.")
                        .font(.echoFootnote)
                        .foregroundStyle(.echoTextSecondary)
                    ConnectAccountsView()
                }
            } else {
                Section {
                    if kind == .user {
                        Picker("What kind?", selection: $category) {
                            ForEach(categories, id: \.self) { Text($0) }
                        }
                    } else {
                        Picker("Part of the app", selection: $area) {
                            ForEach(areas, id: \.self) { Text($0) }
                        }
                        if let user = accounts.account?.githubUsername {
                            Label("Sending as @\(user)", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.echoFootnote)
                        }
                    }
                    TextField(kind == .user ? "Tell us what you think…" : "What should change, and why?",
                              text: $message, axis: .vertical)
                        .lineLimit(5...12)
                } footer: {
                    Text(kind == .user
                         ? "Thanks! This goes to the Echo team. Don't include passwords or private info."
                         : "Echo turns this into a clear change request and commits it to the echo-feedback branch on GitHub for the app's developer.")
                }

                Section {
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSending { ProgressView() } else { Text(kind == .user ? "Send Feedback" : "Send to GitHub") }
                            Spacer()
                        }
                    }
                    .disabled(isSending || message.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)
                }

                if let result {
                    Section("Sent ✓") {
                        Text(result.title).font(.echoHeadline)
                        if let link = result.url {
                            Link("View on GitHub", destination: link)
                        }
                    }
                }
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn't send", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func send() async {
        isSending = true
        defer { isSending = false }
        do {
            result = try await FeedbackClient().send(
                kind: kind == .user ? "user" : "developer",
                category: kind == .user ? category : area,
                message: message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            message = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Client for the echo-feedback function

struct FeedbackClient {
    struct Result: Decodable {
        let title: String
        let url: URL?
    }

    func send(kind: String, category: String, message: String) async throws -> Result {
        let endpoint = URL(string: EchoConfig.supabaseURL)!.appending(path: "functions/v1/echo-feedback")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(EchoConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if let token = await AccountService.shared.accessToken {
            request.setValue(token, forHTTPHeaderField: "x-echo-user-token")
        }
        let body: [String: Any] = [
            "kind": kind,
            "category": category,
            "message": message,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "device": await UIDevice.current.model,
            "osVersion": await UIDevice.current.systemVersion
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw NSError(domain: "Echo", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg ?? "The feedback service isn't available right now."])
        }
        return try JSONDecoder().decode(Result.self, from: data)
    }
}

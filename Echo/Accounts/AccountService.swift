import Foundation
import AuthenticationServices
import CryptoKit
import Security
import UIKit

// MARK: - Accounts (Supabase Auth)
//
//  • Apple  — native Sign in with Apple → Supabase (id_token grant)
//  • Google — Supabase OAuth in a secure web sheet (Gmail accounts)
//  • GitHub — Supabase OAuth; for developers who send feedback to GitHub
//
// One-time Supabase setup (Dashboard → Authentication):
//   Providers → enable Apple (Client IDs: phoronomicstudios.com.Echo), Google, GitHub
//   URL Configuration → Redirect URLs → add  echo://auth-callback

enum AccountProvider: String, Codable, CaseIterable, Identifiable {
    case apple, google, github
    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple:  return "Apple"
        case .google: return "Google (Gmail)"
        case .github: return "GitHub"
        }
    }

    var systemImage: String {
        switch self {
        case .apple:  return "apple.logo"
        case .google: return "envelope.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct EchoAccount: Codable, Equatable {
    var provider: AccountProvider
    var userID: String
    var email: String?
    var displayName: String?
    var githubUsername: String?
}

@Observable
@MainActor
final class AccountService: NSObject {
    static let shared = AccountService()

    private(set) var account: EchoAccount? = AccountService.loadAccount()
    var isWorking = false
    var errorMessage: String? = nil

    var isSignedIn: Bool { account != nil }
    var isDeveloper: Bool { account?.provider == .github }

    /// Current access token for calls to Echo's backend (nil if signed out).
    var accessToken: String? { Keychain.read("echo.accessToken") }

    private var currentNonce: String?
    private var webSession: ASWebAuthenticationSession?

    // MARK: - Apple

    /// Configure the SignInWithAppleButton request.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = "Sign in with Apple didn't finish. \(error.localizedDescription)"
            }
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Apple didn't return a sign-in token."
                return
            }
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }.joined(separator: " ")
            await exchangeAppleToken(idToken: idToken, nonce: nonce, fallbackName: fullName)
        }
    }

    private func exchangeAppleToken(idToken: String, nonce: String, fallbackName: String) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let body = ["provider": "apple", "id_token": idToken, "nonce": nonce]
            let json = try await authRequest(path: "token?grant_type=id_token", method: "POST", body: body)
            try await completeSignIn(provider: .apple, tokenJSON: json, providerToken: nil, fallbackName: fallbackName)
        } catch {
            errorMessage = "Couldn't connect your Apple account. Make sure the Apple provider is enabled in Supabase."
        }
    }

    // MARK: - Google & GitHub (OAuth in a secure web sheet)

    func signIn(with provider: AccountProvider) async {
        guard provider != .apple else { return }
        isWorking = true
        defer { isWorking = false }

        var components = URLComponents(url: authBase.appending(path: "authorize"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider.rawValue),
            URLQueryItem(name: "redirect_to", value: "echo://auth-callback"),
            URLQueryItem(name: "scopes", value: provider == .github ? "read:user user:email" : "email profile")
        ]
        guard let url = components.url else { return }

        do {
            let callback: URL = try await withCheckedThrowingContinuation { cont in
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "echo") { url, error in
                    if let url { cont.resume(returning: url) } else { cont.resume(throwing: error ?? URLError(.cancelled)) }
                }
                session.presentationContextProvider = self
                session.prefersEphemeralWebBrowserSession = false
                self.webSession = session
                session.start()
            }
            // Supabase returns tokens in the URL fragment: #access_token=…&refresh_token=…
            let fragment = callback.fragment ?? callback.query ?? ""
            var params: [String: String] = [:]
            for pair in fragment.split(separator: "&") {
                let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 { params[parts[0]] = parts[1].removingPercentEncoding ?? parts[1] }
            }
            if let message = params["error_description"] {
                errorMessage = message.replacingOccurrences(of: "+", with: " ")
                return
            }
            guard let access = params["access_token"], let refresh = params["refresh_token"] else {
                errorMessage = "Sign-in didn't return a session. Check that \(provider.title) is enabled in Supabase."
                return
            }
            let tokenJSON: [String: Any] = ["access_token": access, "refresh_token": refresh]
            try await completeSignIn(provider: provider, tokenJSON: tokenJSON, providerToken: params["provider_token"], fallbackName: "")
        } catch {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                errorMessage = "Couldn't connect \(provider.title). \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Session

    func signOut() {
        Keychain.delete("echo.accessToken")
        Keychain.delete("echo.refreshToken")
        UserDefaults.standard.removeObject(forKey: Self.accountKey)
        account = nil
    }

    private func completeSignIn(provider: AccountProvider, tokenJSON: [String: Any],
                                providerToken: String?, fallbackName: String) async throws {
        guard let access = tokenJSON["access_token"] as? String,
              let refresh = tokenJSON["refresh_token"] as? String else { throw URLError(.badServerResponse) }
        Keychain.save(access, for: "echo.accessToken")
        Keychain.save(refresh, for: "echo.refreshToken")

        // Who is this?
        let user = try await authRequest(path: "user", method: "GET", body: nil, bearer: access)
        let metadata = user["user_metadata"] as? [String: Any] ?? [:]
        let name = (metadata["full_name"] as? String) ?? (metadata["name"] as? String) ?? (fallbackName.isEmpty ? nil : fallbackName)

        var githubUsername = metadata["user_name"] as? String ?? metadata["preferred_username"] as? String
        if provider == .github, githubUsername == nil, let providerToken {
            githubUsername = await Self.fetchGitHubLogin(token: providerToken)
        }

        let account = EchoAccount(
            provider: provider,
            userID: user["id"] as? String ?? "",
            email: user["email"] as? String,
            displayName: name,
            githubUsername: provider == .github ? githubUsername : nil
        )
        self.account = account
        if let data = try? JSONEncoder().encode(account) { UserDefaults.standard.set(data, forKey: Self.accountKey) }

        // Use their first name for Echo's greeting if they haven't set one.
        if UserProfile.name.isEmpty, let first = name?.split(separator: " ").first {
            UserDefaults.standard.set(String(first), forKey: UserProfile.nameKey)
        }
    }

    // MARK: - Helpers

    private var authBase: URL { URL(string: EchoConfig.supabaseURL)!.appending(path: "auth/v1") }

    private func authRequest(path: String, method: String, body: [String: Any]?, bearer: String? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: authBase.absoluteString + "/" + path)!)
        request.httpMethod = method
        request.setValue(EchoConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.badServerResponse)
        }
        return json
    }

    private static func fetchGitHubLogin(token: String) async -> String? {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["login"] as? String
    }

    private static let accountKey = "echo.account"

    private static func loadAccount() -> EchoAccount? {
        guard let data = UserDefaults.standard.data(forKey: accountKey) else { return nil }
        return try? JSONDecoder().decode(EchoAccount.self, from: data)
    }

    private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AccountService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

// MARK: - Minimal Keychain wrapper (tokens never go in UserDefaults)

enum Keychain {
    static func save(_ value: String, for key: String) {
        delete(key)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: Data(value.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
    }
}

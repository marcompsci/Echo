import Foundation

// MARK: - Backend configuration
//
// Paste your Supabase project values here (Supabase dashboard → Project Settings → API).
// Works with the new publishable key (sb_publishable_…) or a legacy anon JWT.
// That key is designed to be public — it only lets the app call your Edge Function.
// Your Anthropic API key NEVER goes in the app; it lives in Supabase secrets.
//
// While these still contain "YOUR-", Echo keeps using MockGuideService.

enum EchoConfig {
    static let supabaseURL = "https://itjoqbgcwhcancpdfqzu.supabase.co"
    static let supabaseAnonKey = "sb_publishable_chhr0FUcfPJgC3fw4Ym4gg_tOUjSCnq"

    static var isBackendConfigured: Bool {
        !supabaseURL.contains("YOUR-") && !supabaseAnonKey.contains("YOUR-")
    }

    static var guideEndpoint: URL {
        URL(string: supabaseURL)!.appending(path: "functions/v1/echo-guide")
    }

    /// Real Claude-powered guides once configured; sample data until then.
    static func makeGuideService() -> any GuideService {
        if isBackendConfigured { return LiveGuideService() }
        return MockGuideService()
    }
}

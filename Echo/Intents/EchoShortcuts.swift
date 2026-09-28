import AppIntents

// MARK: - Siri Shortcuts for Echo

struct EchoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskEchoIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Open \(.applicationName)",
                "Get help from \(.applicationName)"
            ],
            shortTitle: "Ask Echo",
            systemImageName: "sparkles"
        )
    }
}

/*
 ── Testing Siri Shortcuts ──────────────────────────────────────────────
 1. Build and run on a real device (Shortcuts are not available in Simulator).
 2. Open the Shortcuts app → tap + (New Shortcut) → search "Echo".
 3. You should see "Ask Echo" in the list of Echo actions.
 4. Add it, name it, then run it — Echo should open to the home screen.
 5. To test with Siri: say "Ask Echo", "Open Echo", or "Get help from Echo".

 The `openAppWhenRun = true` flag ensures Echo launches automatically.
 In a future release, the intent can deep-link to AnalyzeView by setting
 `pendingImageData` on AppRouter before returning from `perform()`.
 ────────────────────────────────────────────────────────────────────────
 */

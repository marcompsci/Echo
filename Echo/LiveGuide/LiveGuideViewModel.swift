import Foundation
import UserNotifications

// MARK: - Live Guide (app side)
//
// Sets the goal, hands the guide-service settings to the broadcast extension
// through the App Group, and mirrors the extension's progress on screen.

@Observable
@MainActor
final class LiveGuideViewModel {
    var goal: String = ""
    private(set) var session: LiveGuideSession? = LiveGuideStore.load()
    var errorMessage: String? = nil

    // "Do it for me": when the goal is something Echo Agent can do itself.
    var offeredPlan: AgentPlan? = nil
    var showPlan = false
    var agentResultMessage: String? = nil

    let suggestions = [
        "Turn on Dark Mode",
        "Make the text on my phone bigger",
        "Share my location with a friend",
        "Turn off notifications for an app",
        "Set up a new email account"
    ]

    private var refreshTask: Task<Void, Never>?

    var isActive: Bool {
        guard let status = session?.status else { return false }
        return status == .watching || status == .thinking || status == .error
    }

    var isReadyToBroadcast: Bool { session?.status == .ready }

    var statusLine: String {
        guard let session else { return "Tell Echo what you want to do." }
        switch session.status {
        case .ready:    return "Ready. Tap “Start Screen Sharing” below, then choose Echo."
        case .watching: return "Echo is watching your screen."
        case .thinking: return "Echo is looking at your screen…"
        case .done:     return "All done!"
        case .error:    return session.message ?? "Something went wrong."
        case .ended:    return "Screen sharing stopped."
        }
    }

    /// Saves the goal + guide-service config for the extension, and asks for
    /// notification permission (steps arrive as banners over other apps).
    func prepare(speakAloud: Bool) async {
        let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard EchoConfig.isBackendConfigured else {
            errorMessage = "Live Guide needs Echo's cloud guide service. Add your Supabase keys in EchoConfig.swift."
            return
        }

        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])

        let session = LiveGuideSession(
            goal: trimmed,
            speakAloud: speakAloud,
            endpoint: EchoConfig.guideEndpoint.absoluteString,
            apiKey: EchoConfig.supabaseAnonKey
        )
        LiveGuideStore.save(session)
        self.session = session
        await checkIfEchoCanDoIt(trimmed)
    }

    /// Asks Echo Agent whether it can just do this goal (with permission).
    func checkIfEchoCanDoIt(_ goal: String) async {
        offeredPlan = nil
        agentResultMessage = nil
        guard AppleIntelligence.isAvailable,
              let plan = try? await OnDeviceAgentPlanner().plan(for: AgentRequest(text: goal)),
              !plan.actions.isEmpty else { return }
        offeredPlan = plan
    }

    func runOfferedPlan() async {
        guard let plan = offeredPlan else { return }
        showPlan = false
        do {
            let result = try await LiveAgentService().execute(plan: plan)
            agentResultMessage = result.isFullySuccessful
                ? "Done — Echo handled it."
                : "Echo finished \(result.successCount) of \(plan.actions.count). \(result.failedActions.first?.1 ?? "")"
            if result.isFullySuccessful { offeredPlan = nil }
        } catch {
            agentResultMessage = error.localizedDescription
        }
    }

    func reset() {
        LiveGuideStore.clear()
        session = nil
        goal = ""
        offeredPlan = nil
        agentResultMessage = nil
    }

    func startObserving() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let latest = LiveGuideStore.load()
                if let self, latest?.steps.count != self.session?.steps.count || latest?.status != self.session?.status {
                    self.mirrorToLockScreen(latest)
                }
                self?.session = latest
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    /// Shows the current Live Guide step in the Dynamic Island / Lock Screen.
    private func mirrorToLockScreen(_ session: LiveGuideSession?) {
        guard let session else { return }
        switch session.status {
        case .watching, .thinking:
            if let step = session.currentStep {
                EchoPresence.update(.guiding, step.instruction, step: session.steps.count)
            } else {
                EchoPresence.update(.guiding, "Watching your screen…")
            }
        case .done:
            EchoPresence.update(.done, session.currentStep?.instruction ?? "All done!")
        case .ended, .error, .ready:
            EchoPresence.rest()
        }
    }

    func stopObserving() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

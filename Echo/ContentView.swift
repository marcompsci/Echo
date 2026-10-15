import SwiftUI
import SwiftData

// HomeRootView wires the NavigationStack to AppRouter and resolves all route destinations.
struct HomeRootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var launchCenter = EchoLaunchCenter.shared
    @State private var launchError: String? = nil

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: EchoRoute.self) { route in
                    switch route {
                    case .analyze:
                        if let imageData = router.pendingImageData {
                            AnalyzeView(imageData: imageData)
                        }
                    case .result:
                        if let session = router.currentSession,
                           let response = router.currentGuideResponse {
                            ResultView(
                                session: session,
                                response: response,
                                imageData: router.pendingImageData
                            )
                        }
                    case .agent:
                        AgentView()
                    case .liveGuide:
                        LiveGuideView()
                    case .heyEchoSetup:
                        HeyEchoSetupView()
                    }
                }
        }
        .sheet(isPresented: $router.showSettings) {
            SettingsView()
                .environment(\.modelContext, modelContext)
        }
        .fullScreenCover(isPresented: $router.showHeyEcho, onDismiss: { router.heyEchoGreeting = nil }) {
            HeyEchoView(greeting: router.heyEchoGreeting) { route in
                switch route {
                case .helpWithScreen:
                    launchCenter.request(.lastScreenshot)
                case .walkMeThrough(let goal):
                    router.pendingLiveGoal = goal
                    launchCenter.request(.liveGuide)
                default:
                    break
                }
            }
        }
        .onChange(of: launchCenter.pending, initial: true) { _, request in
            guard let request else { return }
            launchCenter.pending = nil
            Task { await handle(request) }
        }
        .alert("Echo couldn't open that", isPresented: .constant(launchError != nil)) {
            Button("OK") { launchError = nil }
        } message: {
            Text(launchError ?? "")
        }
    }

    // Siri / Action Button / Control Center / Visual Intelligence → the right screen.
    private func handle(_ request: EchoLaunchRequest) async {
        switch request {
        case .agent:
            router.popToHome()
            router.navigateToAgent()
        case .liveGuide:
            router.popToHome()
            router.navigateToLiveGuide()
        case .heyEcho:
            router.heyEchoGreeting = UserProfile.helpGreeting
            router.showHeyEcho = true
        case .capturedScreen(let id):
            guard let data = ScreenCaptureStore.take(id) else {
                launchError = "That screen is no longer available. Try Visual Intelligence again."
                return
            }
            router.popToHome()
            router.navigateToAnalyze(imageData: data)
        case .lastScreenshot:
            do {
                let data = try await ScreenCaptureStore.latestScreenshot()
                router.popToHome()
                router.navigateToAnalyze(imageData: data)
            } catch ScreenCaptureStore.LatestScreenshotError.accessDenied {
                launchError = "Allow Echo to access Photos in Settings so it can open your latest screenshot."
            } catch ScreenCaptureStore.LatestScreenshotError.noScreenshots {
                launchError = "No screenshots found. Press the side button and volume up together to take one."
            } catch {
                launchError = "Echo couldn't load your latest screenshot. Try importing it instead."
            }
        }
    }
}

#Preview {
    HomeRootView()
        .environment(AppRouter())
        .modelContainer(for: EchoSession.self, inMemory: true)
}

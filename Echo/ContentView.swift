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
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "circle.hexagongrid.fill", value: EchoTab.home) {
                homeStack
            }
            Tab("Tools", systemImage: "square.grid.2x2.fill", value: EchoTab.tools) {
                ToolsView()
            }
            Tab("Activity", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90", value: EchoTab.activity) {
                NavigationStack { ActivityLogView() }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: EchoTab.settings) {
                SettingsView(showsDone: false)
                    .environment(\.modelContext, modelContext)
            }
        }
        .tint(.echoLavender)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            HeyEchoAccessory {
                router.heyEchoGreeting = UserProfile.helpGreeting
                router.heyEchoText = nil
                router.showHeyEcho = true
            }
        }
        .modifier(RootPresentations(launchCenter: launchCenter, launchError: $launchError))
    }

    private var homeStack: some View {
        @Bindable var router = router
        return NavigationStack(path: $router.path) {
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
                    case .photoCleanup:
                        PhotoCleanupView()
                    case .fileCleanup:
                        FileCleanupView()
                    }
                }
        }
    }
}

// MARK: - Hey Echo, Siri/Shortcut launches and alerts (shared by every tab)

private struct RootPresentations: ViewModifier {
    @Environment(AppRouter.self) private var router
    let launchCenter: EchoLaunchCenter
    @Binding var launchError: String?

    func body(content: Content) -> some View {
        @Bindable var router = router
        content
        .fullScreenCover(isPresented: $router.showHeyEcho, onDismiss: { router.heyEchoGreeting = nil; router.heyEchoText = nil }) {
            HeyEchoView(greeting: router.heyEchoGreeting, initialText: router.heyEchoText) { route in
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
            router.heyEchoText = nil
            router.showHeyEcho = true
        case .heyEchoWith(let text):
            router.heyEchoGreeting = nil
            router.heyEchoText = text
            router.showHeyEcho = true
        case .liveGuideGoal(let goal):
            router.pendingLiveGoal = goal
            router.popToHome()
            router.navigateToLiveGuide()
        case .photoCleanup:
            router.selectedTab = .home
            router.path.append(EchoRoute.photoCleanup)
        case .fileOrganizer:
            router.selectedTab = .home
            router.path.append(EchoRoute.fileCleanup)
        case .connectAI:
            router.showSettings = true
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

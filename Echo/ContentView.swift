import SwiftUI
import SwiftData

// HomeRootView wires the NavigationStack to AppRouter and resolves all route destinations.
struct HomeRootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

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
                    }
                }
        }
        .sheet(isPresented: $router.showSettings) {
            SettingsView()
                .environment(\.modelContext, modelContext)
        }
    }
}

#Preview {
    HomeRootView()
        .environment(AppRouter())
        .modelContainer(for: EchoSession.self, inMemory: true)
}

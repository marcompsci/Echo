import SwiftUI
import SwiftData

@main
struct EchoApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var router = AppRouter()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([EchoSession.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                HomeRootView()
                    .environment(router)
            } else {
                OnboardingView(onComplete: { hasSeenOnboarding = true })
            }
        }
        .modelContainer(sharedModelContainer)
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    private func handleIncomingURL(_ url: URL) {
        // echo://import — called by the future Share Extension
        guard url.scheme?.lowercased() == "echo",
              url.host?.lowercased() == "import" else { return }
        let inbox = SharedImageInbox()
        if let data = inbox.consumePendingImage() {
            router.navigateToAnalyze(imageData: data)
        }
    }
}

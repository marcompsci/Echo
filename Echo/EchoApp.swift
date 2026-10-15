import SwiftUI
import SwiftData
import WidgetKit

@main
struct EchoApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var router = AppRouter()
    @State private var petState = PetState()
    @AppStorage(EchoAppearance.storageKey) private var appearanceRaw = EchoAppearance.system.rawValue
    @State private var showSplash = true

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
            Group {
                if hasSeenOnboarding {
                    HomeRootView()
                        .environment(router)
                        .environment(petState)
                } else {
                    OnboardingView(onComplete: { hasSeenOnboarding = true })
                }
            }
            .overlay {
                if showSplash {
                    EchoSplashView { showSplash = false }
                        .transition(.identity)
                }
            }
            .preferredColorScheme((EchoAppearance(rawValue: appearanceRaw) ?? .system).colorScheme)
            .task {
                EchoPresence.start()
                EchoWidgetShared.save(userName: UserProfile.name)
                WidgetCenter.shared.reloadTimelines(ofKind: EchoWidgetShared.kind)
            }
            .onOpenURL { url in
                handleIncomingURL(url)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleIncomingURL(_ url: URL) {
        // echo://last-screenshot and echo://agent — Control Center / Action Button
        if EchoLaunchCenter.shared.handle(url: url) { return }
        // echo://import — called by the future Share Extension
        guard url.scheme?.lowercased() == "echo",
              url.host?.lowercased() == "import" else { return }
        let inbox = SharedImageInbox()
        if let data = inbox.consumePendingImage() {
            router.navigateToAnalyze(imageData: data)
        }
    }
}

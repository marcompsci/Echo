import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var bridge: ExtensionBridgeService
    @EnvironmentObject private var voice: VoiceGuidanceService
    @State private var selectedTab: AppTab = .inspector

    enum AppTab { case inspector, guide, history, settings }

    var body: some View {
        TabView(selection: $selectedTab) {
            InspectorView()
                .tabItem { Label("Inspector", systemImage: "viewfinder.circle") }
                .tag(AppTab.inspector)

            VoiceGuidanceView()
                .tabItem { Label("Guide", systemImage: "waveform.circle") }
                .tag(AppTab.guide)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.history)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(.indigo)
        .onChange(of: bridge.lastSnapshot) { _, snap in
            guard snap != nil else { return }
            withAnimation { selectedTab = .inspector }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ExtensionBridgeService.shared)
        .environmentObject(VoiceGuidanceService.shared)
        .modelContainer(for: [DebugSession.self, ElementSnapshot.self, VoiceCommandRecord.self], inMemory: true)
}

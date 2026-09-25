import SwiftUI
import SwiftData

struct InspectorView: View {
    @EnvironmentObject private var bridge: ExtensionBridgeService
    @EnvironmentObject private var voice: VoiceGuidanceService
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DebugSession.timestamp, order: .reverse) private var sessions: [DebugSession]

    @State private var showingDetail: ElementSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusBanner
                    if let snap = bridge.lastSnapshot {
                        elementCard(snap)
                        if !snap.aiSuggestions.isEmpty || !snap.aiInsights.isEmpty {
                            analysisCards(snap)
                        }
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .navigationTitle("Inspector")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Simulate") { bridge.simulateElementSelection() }
                        .font(.caption)
                        .tint(.indigo)
                }
            }
        }
        .onChange(of: bridge.lastSnapshot) { _, snap in
            guard let snap else { return }
            saveSnapshot(snap)
            voice.speak(NLAnalysisService.shared.voiceSummary(for: snap))
        }
        .sheet(item: $showingDetail) { snap in
            ElementDetailView(snapshot: snap)
        }
    }

    // MARK: - Status Banner

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(bridge.connectionStatus.color)
                .frame(width: 8, height: 8)
            Text(bridge.connectionStatus.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !bridge.currentPageURL.isEmpty {
                Text(URL(string: bridge.currentPageURL)?.host ?? "")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Element Card

    private func elementCard(_ snap: ElementSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snap.displayTitle)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(.indigo)
                    if !snap.aiClassification.isEmpty {
                        Text(snap.aiClassification)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.indigo.opacity(0.15), in: Capsule())
                            .foregroundStyle(.indigo)
                    }
                }
                Spacer()
                Button { showingDetail = snap } label: {
                    Image(systemName: "arrow.up.right.square")
                        .imageScale(.large)
                        .foregroundStyle(.indigo)
                }
            }

            if !snap.innerText.isEmpty {
                Text(snap.innerText.prefix(120))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if !snap.xpath.isEmpty {
                Text(snap.xpath)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                ActionChip(icon: "waveform", label: "Speak") {
                    voice.speak(NLAnalysisService.shared.voiceSummary(for: snap))
                }
                ActionChip(icon: "doc.on.doc", label: "Copy HTML") {
                    copyToPasteboard(snap.outerHTML)
                }
                ActionChip(icon: "bookmark", label: "Save") {
                    saveSnapshot(snap)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Analysis Cards

    private func analysisCards(_ snap: ElementSnapshot) -> some View {
        VStack(spacing: 12) {
            if !snap.aiSuggestions.isEmpty {
                AnalysisSection(title: "Suggestions", icon: "exclamationmark.triangle",
                                accentColor: .orange, items: snap.aiSuggestions)
            }
            if !snap.aiInsights.isEmpty {
                AnalysisSection(title: "Insights", icon: "lightbulb",
                                accentColor: .indigo, items: snap.aiInsights)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "viewfinder.circle")
                .font(.system(size: 52))
                .foregroundStyle(.indigo.opacity(0.4))
            Text("Enable Echo in Safari")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap the Safari toolbar icon, then enable the extension. Switch to Inspect mode and click any element on the page.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func copyToPasteboard(_ string: String) {
        #if os(iOS)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }

    private func saveSnapshot(_ snap: ElementSnapshot) {
        let session: DebugSession
        if let existing = sessions.first(where: { $0.pageURL == snap.pageURL && $0.isActive }) {
            session = existing
        } else {
            session = DebugSession(pageURL: snap.pageURL, pageTitle: snap.pageTitle)
            modelContext.insert(session)
        }
        session.snapshots.append(snap)
    }
}

// MARK: - Supporting Views

struct ActionChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

struct AnalysisSection: View {
    let title: String
    let icon: String
    let accentColor: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColor)

            ForEach(items.prefix(4), id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: 3)
                        .padding(.top, 3)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

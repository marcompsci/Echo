import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DebugSession.timestamp, order: .reverse) private var sessions: [DebugSession]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSession: DebugSession?
    @State private var searchText = ""

    var filteredSessions: [DebugSession] {
        guard !searchText.isEmpty else { return sessions }
        return sessions.filter {
            $0.pageTitle.localizedCaseInsensitiveContains(searchText) ||
            $0.pageURL.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(filteredSessions) { session in
                            SessionRow(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedSession = session }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .listStyle(.insetGrouped)
                    .searchable(text: $searchText, prompt: "Search sessions")
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !sessions.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        EditButton()
                    }
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Inspection History")
                .font(.headline)
            Text("Sessions are saved automatically when you inspect elements.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredSessions[index])
        }
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: DebugSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.pageTitle.isEmpty ? session.domain : session.pageTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(session.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(session.domain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "viewfinder")
                        .font(.caption2)
                    Text("\(session.snapshots.count) element\(session.snapshots.count == 1 ? "" : "s")")
                        .font(.caption2)
                }
                .foregroundStyle(.indigo)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    let session: DebugSession
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var voice: VoiceGuidanceService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Page", value: session.pageTitle.isEmpty ? "Untitled" : session.pageTitle)
                    LabeledContent("URL", value: session.domain)
                    LabeledContent("Date", value: session.timestamp.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Elements", value: "\(session.snapshots.count)")
                }

                if !session.snapshots.isEmpty {
                    Section("Inspected Elements") {
                        ForEach(session.snapshots) { snap in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snap.displayTitle)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.indigo)
                                if !snap.aiClassification.isEmpty {
                                    Text(snap.aiClassification)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if !snap.aiSuggestions.isEmpty {
                                    Text("\(snap.aiSuggestions.count) suggestion(s)")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let summary = "Session from \(session.domain) with \(session.snapshots.count) elements inspected."
                        voice.speak(summary)
                    } label: {
                        Image(systemName: "waveform")
                    }
                    .tint(.indigo)
                }
            }
        }
    }
}

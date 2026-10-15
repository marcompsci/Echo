import SwiftUI

// MARK: - What Echo Did (activity log with Undo)

struct ActivityLogView: View {
    /// "Activity" with a large title when shown as a tab.
    var asTab = false
    @State private var log = ActivityLog.shared
    @AppStorage(EchoAutonomy.storageKey) private var autonomyRaw = EchoAutonomy.askEveryTime.rawValue
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                Picker("How independent is Echo?", selection: $autonomyRaw) {
                    ForEach(EchoAutonomy.allCases) { level in
                        Text(level.title).tag(level.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Text((EchoAutonomy(rawValue: autonomyRaw) ?? .askEveryTime).detail)
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
                Text("Echo never sends a message, places a call, or deletes your photos or contacts on its own. You always tap Send or Call yourself.")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
            } header: {
                Text("Permission")
            }
            .listRowBackground(Color.echoSurface)

            Section {
                if log.entries.isEmpty {
                    Text("Echo hasn't done anything yet.")
                        .foregroundStyle(.echoTextSecondary)
                }
                ForEach(log.entries) { entry in
                    HStack(alignment: .top, spacing: EchoSpacing.sm) {
                        Image(systemName: entry.icon)
                            .foregroundStyle(.echoLavender)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.summary)
                                .foregroundStyle(entry.status == .undone ? Color.echoTextTertiary : Color.echoTextPrimary)
                                .strikethrough(entry.status == .undone)
                            Text("\(statusText(entry.status)) · \(entry.origin) · \(entry.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.echoCaption)
                                .foregroundStyle(.echoTextTertiary)
                            if let detail = entry.detail {
                                Text(detail)
                                    .font(.echoCaption)
                                    .foregroundStyle(.echoDestructive)
                            }
                        }
                        Spacer()
                        if entry.canUndo {
                            Button("Undo") { Task { await log.undo(entry) } }
                                .buttonStyle(.bordered)
                                .tint(.echoLavender)
                                .accessibilityLabel(entry.undo?.label ?? "Undo")
                        }
                    }
                }
            } header: {
                Text("What Echo did")
            }
            .listRowBackground(Color.echoSurface)

            if !log.entries.isEmpty {
                Section {
                    Button("Clear history", role: .destructive) { confirmClear = true }
                }
                .listRowBackground(Color.echoSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .echoScreenBackground()
        .navigationTitle(asTab ? "Activity" : "Trust & Undo")
        .navigationBarTitleDisplayMode(asTab ? .large : .inline)
        .confirmationDialog("Clear Echo's activity history? (This doesn't undo anything.)", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear history", role: .destructive) { log.clear() }
        }
    }

    private func statusText(_ status: ActivityEntry.Status) -> String {
        switch status {
        case .done: return "Done"
        case .handedOff: return "Opened for you"
        case .failed: return "Didn't work"
        case .undone: return "Undone"
        }
    }
}

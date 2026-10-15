import SwiftUI

// MARK: - Developer Mode: live request inspector + Echo's open hooks

struct DevInspectorView: View {
    @State private var inspector = DevInspector.shared

    var body: some View {
        List {
            Section {
                ForEach(Self.hooks, id: \.0) { hook in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hook.0)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(.echoTextPrimary)
                            .textSelection(.enabled)
                        Text(hook.1)
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextTertiary)
                    }
                }
            } header: {
                Text("Build on Echo")
            } footer: {
                Text("Shortcuts actions: Ask Echo a Question (returns text), Remember with Echo, Undo Echo's Last Action, Hey Echo, Start Live Guide. They chain with any app that supports Shortcuts.")
            }
            .listRowBackground(Color.echoSurface)

            Section {
                if inspector.traces.isEmpty {
                    Text("Use Echo and requests show up here.")
                        .foregroundStyle(.echoTextSecondary)
                }
                ForEach(inspector.traces) { trace in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: trace.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(trace.succeeded ? Color.green : Color.echoDestructive)
                            Text("\(trace.feature) · \(trace.engine)")
                                .font(.echoSubheadline)
                                .foregroundStyle(.echoTextPrimary)
                            Spacer()
                            Text("\(trace.latencyMs) ms")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.echoTextSecondary)
                        }
                        Text("In: \(trace.input.isEmpty ? "—" : trace.input)")
                            .font(.echoCaption).foregroundStyle(.echoTextSecondary)
                        Text("Out: \(trace.outcome)")
                            .font(.echoCaption).foregroundStyle(.echoTextSecondary)
                        HStack(spacing: 8) {
                            if let bytes = trace.payloadBytes {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
                            }
                            if trace.usedPersonalContext { Text("+ personal context") }
                            if !trace.hidden.isEmpty { Text("Shield hid: \(trace.hidden.joined(separator: ", "))") }
                            Text(trace.date.formatted(date: .omitted, time: .standard))
                        }
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.echoTextTertiary)
                    }
                    .textSelection(.enabled)
                }
            } header: {
                HStack {
                    Text("Requests (this session)")
                    Spacer()
                    if !inspector.traces.isEmpty { Button("Clear") { inspector.clear() } }
                }
            }
            .listRowBackground(Color.echoSurface)
        }
        .scrollContentBackground(.hidden)
        .echoScreenBackground()
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
    }

    static let hooks: [(String, String)] = [
        ("echo://hey", "Open Echo listening"),
        ("echo://ask?q=How do I share my location", "Ask Echo out loud from any app or link"),
        ("echo://do?task=Remind me to stretch at 3pm", "Plan a task in Echo Agent (you approve it)"),
        ("echo://remember?text=My gym is Crunch", "Add to Echo's memory"),
        ("echo://live?goal=Turn on Wi-Fi", "Start Live Guide with a goal"),
        ("echo://last-screenshot", "Analyze your latest screenshot"),
        ("echo://skill?name=Good morning", "Run one of your Echo Skills")
    ]
}

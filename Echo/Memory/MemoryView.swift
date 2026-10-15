import SwiftUI

// MARK: - What Echo Remembers (Settings)

struct MemoryView: View {
    @State private var memory = EchoMemory.shared
    @State private var newFact = ""
    @State private var editing: MemoryFact? = nil
    @State private var editText = ""
    @State private var error: String? = nil
    @State private var confirmForgetAll = false

    var body: some View {
        List {
            Section {
                Toggle("Use memory", isOn: Binding(get: { memory.isEnabled }, set: { memory.isEnabled = $0 }))
                    .tint(.echoLavender)
                Text("Echo only remembers what you tell it to. Say “Hey Echo, remember my gym is Crunch on Market St.” Memory stays on this iPhone and is shared with the AI only as background for your own questions.")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
            }
            .listRowBackground(Color.echoSurface)

            Section("Add something") {
                HStack {
                    TextField("e.g. My mom's name is Denise", text: $newFact, axis: .vertical)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(newFact.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundStyle(.echoLavender)
                }
            }
            .listRowBackground(Color.echoSurface)

            Section {
                if memory.facts.isEmpty {
                    Text("Nothing yet.")
                        .foregroundStyle(.echoTextSecondary)
                }
                ForEach(memory.facts) { fact in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fact.text)
                            .foregroundStyle(.echoTextPrimary)
                        Text("\(fact.source == .voice ? "Said" : fact.source == .shortcut ? "From Shortcuts" : "Typed") · \(fact.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextTertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editing = fact; editText = fact.text }
                    .swipeActions {
                        Button("Forget", role: .destructive) { memory.forget(fact) }
                    }
                }
            } header: {
                Text("Echo remembers (\(memory.facts.count))")
            }
            .listRowBackground(Color.echoSurface)

            if !memory.facts.isEmpty {
                Section {
                    Button("Forget everything", role: .destructive) { confirmForgetAll = true }
                }
                .listRowBackground(Color.echoSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.echoBackground)
        .navigationTitle("What Echo Remembers")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Edit memory", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Memory", text: $editText)
            Button("Save") {
                if let editing {
                    do { try memory.update(editing, text: editText) } catch { self.error = error.localizedDescription }
                }
                editing = nil
            }
            Button("Cancel", role: .cancel) { editing = nil }
        }
        .alert("Echo can't save that", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .confirmationDialog("Forget everything Echo remembers?", isPresented: $confirmForgetAll, titleVisibility: .visible) {
            Button("Forget everything", role: .destructive) { memory.forgetAll() }
        }
    }

    private func add() {
        do {
            try memory.remember(newFact)
            newFact = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
}

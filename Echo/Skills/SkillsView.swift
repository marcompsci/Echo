import SwiftUI

// MARK: - Echo Skills (Settings)

struct SkillsView: View {
    @State private var store = EchoSkillStore.shared
    @State private var editing: EchoSkill? = nil

    var body: some View {
        List {
            Section {
                Text("Teach Echo your own commands. When you say the phrase to Hey Echo, it runs instantly on your iPhone — no AI guessing. Connect a Shortcut to make Echo do almost anything.")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
                Button {
                    editing = EchoSkill(name: "", phrases: [""], action: .say(""))
                } label: {
                    Label("New Skill", systemImage: "plus.circle.fill")
                        .foregroundStyle(.echoLavender)
                }
            }
            .listRowBackground(Color.echoSurface)

            Section("Your Skills") {
                if store.skills.isEmpty {
                    Text("No skills yet. Start from an idea below.")
                        .foregroundStyle(.echoTextSecondary)
                }
                ForEach(store.skills) { skill in
                    Button { editing = skill } label: {
                        HStack {
                            Image(systemName: skill.action.icon)
                                .foregroundStyle(.echoLavender)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(skill.name.isEmpty ? "Untitled" : skill.name)
                                    .foregroundStyle(.echoTextPrimary)
                                Text("“\(skill.phrases.first ?? "")” → \(skill.action.kindTitle)")
                                    .font(.echoCaption)
                                    .foregroundStyle(.echoTextTertiary)
                            }
                            Spacer()
                            if !skill.isEnabled {
                                Text("Off").font(.echoCaption).foregroundStyle(.echoTextTertiary)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { store.delete(skill) }
                        Button(skill.isEnabled ? "Turn off" : "Turn on") { store.toggle(skill) }
                    }
                }
            }
            .listRowBackground(Color.echoSurface)

            Section("Ideas") {
                ForEach(EchoSkillStore.templates) { template in
                    Button {
                        var copy = template
                        copy.id = UUID()
                        editing = copy
                    } label: {
                        Label("“\(template.phrases[0])” → \(template.action.kindTitle)", systemImage: template.action.icon)
                            .foregroundStyle(.echoTextPrimary)
                    }
                }
            }
            .listRowBackground(Color.echoSurface)
        }
        .scrollContentBackground(.hidden)
        .echoScreenBackground()
        .navigationTitle("Echo Skills")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { skill in
            SkillEditorView(skill: skill) { saved in
                store.save(saved)
                editing = nil
            }
        }
    }
}

struct SkillEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var phrases: String
    @State private var kind: SkillAction.Kind
    @State private var value: String
    private let original: EchoSkill
    let onSave: (EchoSkill) -> Void

    init(skill: EchoSkill, onSave: @escaping (EchoSkill) -> Void) {
        original = skill
        self.onSave = onSave
        _name = State(initialValue: skill.name)
        _phrases = State(initialValue: skill.phrases.joined(separator: ", "))
        _kind = State(initialValue: skill.action.kind)
        _value = State(initialValue: skill.action.value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Good morning", text: $name)
                }
                Section {
                    TextField("good morning, morning echo", text: $phrases)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("When I say…")
                } footer: {
                    Text("Separate different phrases with commas.")
                }
                Section("Echo will…") {
                    Picker("Action", selection: $kind) {
                        ForEach(SkillAction.Kind.allCases) { Text($0.title).tag($0) }
                    }
                    TextField(kind.placeholder, text: $value, axis: .vertical)
                        .textInputAutocapitalization(kind == .openURL ? .never : .sentences)
                        .keyboardType(kind == .openURL ? .URL : .default)
                }
            }
            .navigationTitle(original.name.isEmpty ? "New Skill" : "Edit Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var skill = original
                        skill.name = name.trimmingCharacters(in: .whitespaces)
                        skill.phrases = phrases.split(separator: ",").map(String.init)
                        skill.action = kind.make(value.trimmingCharacters(in: .whitespacesAndNewlines))
                        onSave(skill)
                    }
                    .disabled(phrases.trimmingCharacters(in: .whitespaces).isEmpty
                              || value.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

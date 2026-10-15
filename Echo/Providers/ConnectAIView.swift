import SwiftUI

// MARK: - Settings → Connect AI

struct ConnectAIView: View {
    @State private var refresh = 0

    var body: some View {
        List {
            Section {
                Text("Use your own Claude, ChatGPT, Grok or Muse account for different jobs. Paste an API key from each company's developer site — your key stays in this iPhone's Keychain and goes straight to that company, never to Echo's server. Privacy Shield still hides secrets in screenshots first.")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
            }
            .listRowBackground(Color.echoSurface)

            Section("Who does what") {
                ForEach(AITask.allCases) { task in
                    TaskRoutePicker(task: task, refresh: refresh)
                }
            }
            .listRowBackground(Color.echoSurface)

            Section("Accounts") {
                ForEach(AIProvider.allCases) { provider in
                    NavigationLink {
                        ProviderDetailView(provider: provider) { refresh += 1 }
                    } label: {
                        HStack {
                            Label(provider.name, systemImage: provider.icon)
                            Spacer()
                            Text(AIConnections.isConnected(provider) ? "Connected" : (provider.needsKey ? "Add key" : "Unavailable"))
                                .font(.echoFootnote)
                                .foregroundStyle(AIConnections.isConnected(provider) ? Color.green : Color.echoTextTertiary)
                        }
                    }
                    .id("\(provider.rawValue)-\(refresh)")
                }
            }
            .listRowBackground(Color.echoSurface)

            Section {
                Text("Note: ChatGPT Plus, Claude Pro/Max, SuperGrok and Meta AI subscriptions can't be shared with other apps — each company only lets apps connect with a developer API key, billed by usage. Claude Code is a Mac/terminal tool; on iPhone, Echo uses the same Claude models through your Anthropic key.")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
            }
            .listRowBackground(Color.echoSurface)
        }
        .scrollContentBackground(.hidden)
        .echoScreenBackground()
        .navigationTitle("Connect AI")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TaskRoutePicker: View {
    let task: AITask
    let refresh: Int
    @State private var selection: AIProvider

    init(task: AITask, refresh: Int) {
        self.task = task
        self.refresh = refresh
        _selection = State(initialValue: AIConnections.provider(for: task))
    }

    var body: some View {
        Picker(selection: $selection) {
            ForEach(AIProvider.allCases.filter { AIConnections.isConnected($0) }) { p in
                Text(p.name).tag(p)
            }
        } label: {
            Label(task.title, systemImage: task.icon)
        }
        .onChange(of: selection) { _, new in AIConnections.setProvider(new, for: task) }
    }
}

private struct ProviderDetailView: View {
    let provider: AIProvider
    let onChange: () -> Void
    @State private var key = ""
    @State private var model = ""
    @State private var endpoint = ""
    @State private var testing = false
    @State private var testResult: String? = nil
    @State private var connected = false

    var body: some View {
        List {
            Section {
                Label(provider.strengths, systemImage: provider.icon)
                    .font(.echoSubheadline)
            }
            .listRowBackground(Color.echoSurface)

            if provider.needsKey {
                Section {
                    SecureField(connected ? "Key saved — paste to replace" : "Paste your key (\(provider.keyPrefixHint))", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let url = provider.keyURL {
                        Link("Get a key from \(provider.company)", destination: url)
                            .foregroundStyle(.echoLavender)
                    }
                } header: {
                    Text("\(provider.company) API key")
                } footer: {
                    Text("Stored in the iPhone Keychain. Usage is billed by \(provider.company) to your account.")
                }
                .listRowBackground(Color.echoSurface)

                Section("Model") {
                    TextField(provider.defaultModel, text: $model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(provider.defaultEndpoint, text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.echoFootnote)
                }
                .listRowBackground(Color.echoSurface)

                Section {
                    Button("Save") { save() }
                        .foregroundStyle(.echoLavender)
                    Button {
                        Task { await test() }
                    } label: {
                        HStack { Text("Test connection"); if testing { Spacer(); ProgressView() } }
                    }
                    .disabled(!connected && key.isEmpty)
                    if let testResult {
                        Text(testResult).font(.echoFootnote)
                    }
                    if connected {
                        Button("Disconnect \(provider.name)", role: .destructive) {
                            AIConnections.setKey(nil, for: provider)
                            connected = false
                            testResult = "Disconnected. Your key was removed from this iPhone."
                            onChange()
                        }
                    }
                }
                .listRowBackground(Color.echoSurface)
            } else {
                Section {
                    Text(provider == .apple
                         ? (AppleIntelligence.isAvailable ? "Ready on this iPhone." : AppleIntelligence.statusDescription)
                         : "Always available. No key needed.")
                }
                .listRowBackground(Color.echoSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .echoScreenBackground()
        .navigationTitle(provider.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            connected = AIConnections.isConnected(provider)
            let m = AIConnections.model(for: provider)
            model = m == provider.defaultModel ? "" : m
            let e = AIConnections.endpoint(for: provider)
            endpoint = e == provider.defaultEndpoint ? "" : e
        }
    }

    private func save() {
        if !key.isEmpty { AIConnections.setKey(key, for: provider) }
        AIConnections.setModel(model, for: provider)
        AIConnections.setEndpoint(endpoint, for: provider)
        key = ""
        connected = AIConnections.isConnected(provider)
        testResult = connected ? "Saved." : "Add a key to connect."
        onChange()
    }

    private func test() async {
        save()
        testing = true
        defer { testing = false }
        do {
            let reply = try await ExternalAIClient(provider: provider).test()
            testResult = "✓ \(provider.name) answered: “\(reply.prefix(40))”"
        } catch {
            testResult = error.localizedDescription
        }
    }
}

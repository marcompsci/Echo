import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

// MARK: - File Cleanup & Organizer
//
// Works in Echo's own documents, plus any folder you choose in Files
// (iCloud Drive, On My iPhone, Downloads…). Echo can sort files into folders
// by type, find exact duplicates, and delete what YOU pick — after asking.

nonisolated struct FileEntry: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    let name: String
    let bytes: Int64
    let modified: Date?
    let kind: FileKind
}

nonisolated enum FileKind: String, CaseIterable, Sendable {
    case images = "Images", videos = "Videos", documents = "Documents", audio = "Audio",
         archives = "Archives", code = "Code", other = "Other"

    static func of(_ url: URL) -> FileKind {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return .other }
        if type.conforms(to: .image) { return .images }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .videos }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .archive) { return .archives }
        if type.conforms(to: .sourceCode) || type.conforms(to: .json) || type.conforms(to: .script) { return .code }
        if type.conforms(to: .pdf) || type.conforms(to: .text) || type.conforms(to: .presentation)
            || type.conforms(to: .spreadsheet) || type.conforms(to: .rtf) || url.pathExtension.lowercased() == "docx" { return .documents }
        return .other
    }
}

@Observable
@MainActor
final class FileCleanupModel {
    var folder: URL? = nil
    var files: [FileEntry] = []
    var duplicates: [[FileEntry]] = []
    var selected: Set<URL> = []
    var busy = false
    var message: String? = nil
    private var scoped = false

    var folderName: String { folder?.lastPathComponent ?? "Echo Documents" }

    func useEchoFolder() async {
        stopAccess()
        let agent = FileAgent()
        try? await agent.ensureEchoFolder()
        folder = await agent.echoFolderURL
        await load()
    }

    func use(pickedFolder url: URL) async {
        stopAccess()
        scoped = url.startAccessingSecurityScopedResource()
        folder = url
        await load()
    }

    func load() async {
        guard let folder else { return }
        busy = true
        defer { busy = false }
        let list = await Task.detached { Self.list(folder) }.value
        files = list.sorted { $0.bytes > $1.bytes }
        duplicates = await Task.detached { Self.findDuplicates(list) }.value
    }

    nonisolated static func list(_ folder: URL) -> [FileEntry] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let e = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys,
                                                      options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var out: [FileEntry] = []
        for case let url as URL in e {
            guard let v = try? url.resourceValues(forKeys: Set(keys)), v.isRegularFile == true else { continue }
            out.append(FileEntry(url: url, name: url.lastPathComponent, bytes: Int64(v.fileSize ?? 0),
                                 modified: v.contentModificationDate, kind: FileKind.of(url)))
            if out.count >= 2000 { break }
        }
        return out
    }

    nonisolated static func findDuplicates(_ files: [FileEntry]) -> [[FileEntry]] {
        let bySize = Dictionary(grouping: files.filter { $0.bytes > 0 }, by: \.bytes).values.filter { $0.count > 1 }
        var groups: [[FileEntry]] = []
        for candidates in bySize {
            var byHash: [String: [FileEntry]] = [:]
            for f in candidates where f.bytes < 300_000_000 {
                guard let data = try? Data(contentsOf: f.url, options: .mappedIfSafe) else { continue }
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                byHash[hash, default: []].append(f)
            }
            groups.append(contentsOf: byHash.values.filter { $0.count > 1 })
        }
        return groups
    }

    /// Moves every file at the top of the folder into Images/, Documents/, Videos/… (nothing is deleted).
    func sortByType() async {
        guard let folder else { return }
        busy = true
        defer { busy = false }
        let fm = FileManager.default
        var moved = 0
        let top = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey],
                                               options: [.skipsHiddenFiles])) ?? []
        for url in top where (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true {
            let dest = folder.appendingPathComponent(FileKind.of(url).rawValue, isDirectory: true)
            try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
            var target = dest.appendingPathComponent(url.lastPathComponent)
            var n = 1
            while fm.fileExists(atPath: target.path) {
                target = dest.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent) \(n).\(url.pathExtension)")
                n += 1
            }
            if (try? fm.moveItem(at: url, to: target)) != nil { moved += 1 }
        }
        ActivityLog.shared.record(ActivityEntry(batch: UUID(), summary: "Sorted \(moved) files in “\(folderName)” into folders by type",
                                                icon: "folder.badge.gearshape", origin: "File Cleanup", status: .done))
        message = moved == 0 ? "Everything was already sorted." : "Sorted \(moved) files into folders. Nothing was deleted."
        await load()
    }

    func selectDuplicateCopies() {
        for group in duplicates {
            let keep = group.min { ($0.modified ?? .distantPast) < ($1.modified ?? .distantPast) }
            for f in group where f != keep { selected.insert(f.url) }
        }
    }

    /// Only after the person confirmed. Uses the Files "Recently Deleted" bin when the location supports it.
    func deleteSelected() async {
        let urls = Array(selected)
        guard !urls.isEmpty else { return }
        busy = true
        defer { busy = false }
        var trashed = 0, removed = 0, failed = 0
        for url in urls {
            if (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) != nil { trashed += 1 }
            else if (try? FileManager.default.removeItem(at: url)) != nil { removed += 1 }
            else { failed += 1 }
        }
        ActivityLog.shared.record(ActivityEntry(batch: UUID(), summary: "Deleted \(trashed + removed) files from “\(folderName)”",
                                                icon: "trash", origin: "File Cleanup", status: .done,
                                                detail: trashed > 0 ? "\(trashed) can be restored from Files → Recently Deleted." : nil))
        message = "Deleted \(trashed + removed).\(trashed > 0 ? " \(trashed) are in Files → Recently Deleted." : "")\(failed > 0 ? " \(failed) couldn't be deleted." : "")"
        selected.removeAll()
        await load()
    }

    func stopAccess() {
        if scoped, let folder { folder.stopAccessingSecurityScopedResource() }
        scoped = false
    }
}

struct FileCleanupView: View {
    @State private var model = FileCleanupModel()
    @State private var pickFolder = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                HStack {
                    Label(model.folderName, systemImage: "folder")
                    Spacer()
                    if model.busy { ProgressView() }
                }
                Button("Choose a folder in Files…") { pickFolder = true }
                    .foregroundStyle(.echoLavender)
                Text("Echo only sees the folders you choose. Sorting moves files into folders by type; it never deletes.")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
            }
            .listRowBackground(Color.echoSurface)

            Section {
                Button { Task { await model.sortByType() } } label: {
                    Label("Sort into folders by type", systemImage: "folder.badge.gearshape")
                }
                Button { model.selectDuplicateCopies() } label: {
                    Label("Select duplicate copies (\(model.duplicates.reduce(0) { $0 + $1.count - 1 }))", systemImage: "square.on.square")
                }
                .disabled(model.duplicates.isEmpty)
            } header: { Text("Organize") }
            .listRowBackground(Color.echoSurface)

            Section {
                if model.files.isEmpty { Text("No files here yet.").foregroundStyle(.echoTextSecondary) }
                ForEach(model.files.prefix(300)) { file in
                    Button {
                        if model.selected.contains(file.url) { model.selected.remove(file.url) } else { model.selected.insert(file.url) }
                    } label: {
                        HStack {
                            Image(systemName: model.selected.contains(file.url) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(.echoLavender)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name).foregroundStyle(.echoTextPrimary).lineLimit(1)
                                Text("\(file.kind.rawValue) · \(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))")
                                    .font(.echoCaption).foregroundStyle(.echoTextTertiary)
                            }
                        }
                    }
                }
            } header: { Text("Files (largest first)") }
            .listRowBackground(Color.echoSurface)

            if let message = model.message {
                Section { Text(message).font(.echoFootnote) }.listRowBackground(Color.echoSurface)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.echoBackground)
        .navigationTitle("File Cleanup")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if !model.selected.isEmpty {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete \(model.selected.count) selected", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.echoDestructive)
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .confirmationDialog("Delete \(model.selected.count) file\(model.selected.count == 1 ? "" : "s")?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { Task { await model.deleteSelected() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only the files you picked. Where Files supports it, they go to Recently Deleted.")
        }
        .fileImporter(isPresented: $pickFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result { Task { await model.use(pickedFolder: url) } }
        }
        .task { if model.folder == nil { await model.useEchoFolder() } }
        .onDisappear { model.stopAccess() }
    }
}

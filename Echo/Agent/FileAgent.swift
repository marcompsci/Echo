import Foundation

// MARK: - File operations in the app sandbox and iCloud Drive

actor FileAgent {
    private let fm = FileManager.default

    // App-specific documents directory
    var documentsURL: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // Echo subfolder inside documents
    var echoFolderURL: URL {
        documentsURL.appendingPathComponent("Echo Documents", isDirectory: true)
    }

    // iCloud Drive container (nil if iCloud not available)
    var iCloudURL: URL? {
        fm.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }

    // MARK: - Setup

    func ensureEchoFolder() throws {
        if !fm.fileExists(atPath: echoFolderURL.path) {
            try fm.createDirectory(at: echoFolderURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Enumerate

    struct FileInfo: Sendable, Identifiable {
        let id: String   // absolute path
        let name: String
        let path: String
        let size: Int64
        let modifiedAt: Date?
        let isDirectory: Bool

        var formattedSize: String {
            isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }

    func listFiles(in directory: URL? = nil) throws -> [FileInfo] {
        let dir = directory ?? echoFolderURL
        try ensureEchoFolder()
        let urls = try fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        return urls.compactMap { url in
            let vals = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            return FileInfo(
                id: url.path,
                name: url.lastPathComponent,
                path: url.path,
                size: Int64(vals?.fileSize ?? 0),
                modifiedAt: vals?.contentModificationDate,
                isDirectory: vals?.isDirectory ?? false
            )
        }
    }

    // MARK: - Read

    func readText(at path: String) throws -> String {
        try String(contentsOfFile: path, encoding: .utf8)
    }

    func readData(at path: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: path))
    }

    // MARK: - Write / Create

    func createTextFile(name: String, content: String, in directory: URL? = nil) throws -> URL {
        let dir = directory ?? echoFolderURL
        try ensureEchoFolder()
        var url = dir.appendingPathComponent(name)
        // Avoid overwriting — append suffix if needed
        if fm.fileExists(atPath: url.path) {
            let base = url.deletingPathExtension().lastPathComponent
            let ext  = url.pathExtension
            var i = 1
            repeat {
                url = dir.appendingPathComponent("\(base) \(i).\(ext)")
                i += 1
            } while fm.fileExists(atPath: url.path)
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func createFolder(named name: String, in directory: URL? = nil) throws -> URL {
        let dir = directory ?? echoFolderURL
        try ensureEchoFolder()
        let newDir = dir.appendingPathComponent(name, isDirectory: true)
        try fm.createDirectory(at: newDir, withIntermediateDirectories: true)
        return newDir
    }

    // MARK: - Delete

    func delete(path: String) throws {
        try fm.removeItem(atPath: path)
    }

    // MARK: - Move / Rename

    func rename(path: String, to newName: String) throws -> URL {
        let url = URL(fileURLWithPath: path)
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fm.moveItem(at: url, to: newURL)
        return newURL
    }

    func move(from sourcePath: String, to destinationDirectory: String, newName: String? = nil) throws -> URL {
        let srcURL = URL(fileURLWithPath: sourcePath)
        let destDir = URL(fileURLWithPath: destinationDirectory, isDirectory: true)
        let destURL = destDir.appendingPathComponent(newName ?? srcURL.lastPathComponent)
        try fm.moveItem(at: srcURL, to: destURL)
        return destURL
    }

    // MARK: - iCloud

    func syncToiCloud(localPath: String) async throws {
        guard let iCloud = iCloudURL else {
            throw EchoAgentError.executionFailed("iCloud Drive is not available on this device.")
        }
        let local = URL(fileURLWithPath: localPath)
        let dest  = iCloud.appendingPathComponent(local.lastPathComponent)
        if !fm.fileExists(atPath: iCloud.path) {
            try fm.createDirectory(at: iCloud, withIntermediateDirectories: true)
        }
        try fm.copyItem(at: local, to: dest)
        try fm.startDownloadingUbiquitousItem(at: dest)
    }
}

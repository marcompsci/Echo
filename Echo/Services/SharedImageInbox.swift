import Foundation

// MARK: - Shared Image Inbox
// Reads images deposited by a future Share Extension via the App Group.
// See ShareExtensionSetup.md for how to configure the extension target.

struct SharedImageInbox: Sendable {
    // Replace with your actual App Group identifier when provisioning.
    static let appGroupID = "group.com.yourcompany.echo"
    static let pendingImageKey = "pending_shared_image"
    static let pendingImageFilename = "pending_share.jpg"

    private var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupID
        )
    }

    // Returns image data deposited by the Share Extension, if any.
    func consumePendingImage() -> Data? {
        guard let dir = containerURL else { return nil }
        let file = dir.appendingPathComponent(Self.pendingImageFilename)
        guard let data = try? Data(contentsOf: file) else { return nil }
        try? FileManager.default.removeItem(at: file)
        return data
    }

    var hasPendingImage: Bool {
        guard let dir = containerURL else { return false }
        return FileManager.default.fileExists(
            atPath: dir.appendingPathComponent(Self.pendingImageFilename).path
        )
    }
}

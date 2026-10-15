import Foundation
import Photos
import UIKit
import CoreGraphics

// MARK: - Screens handed to Echo
//
// • Visual Intelligence captures (saved briefly to Caches, then deleted)
// • The person's most recent screenshot from Photos

nonisolated enum ScreenCaptureStore {

    private static var directory: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EchoCaptures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func url(for id: String) -> URL {
        directory.appendingPathComponent("\(id).jpg")
    }

    /// Saves a captured screen; returns its id. Old captures (> 1 hour) are pruned.
    static func save(_ image: CGImage) -> String? {
        prune()
        let id = UUID().uuidString
        guard let data = UIImage(cgImage: image).jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try data.write(to: url(for: id), options: [.atomic, .completeFileProtection])
            return id
        } catch {
            return nil
        }
    }

    static func exists(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id).path)
    }

    /// Returns and deletes the capture (Echo never keeps it unless the person saves the guide).
    static func take(_ id: String) -> Data? {
        let file = url(for: id)
        defer { try? FileManager.default.removeItem(at: file) }
        return try? Data(contentsOf: file)
    }

    private static func prune() {
        let cutoff = Date.now.addingTimeInterval(-3600)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if let modified, modified < cutoff { try? FileManager.default.removeItem(at: file) }
        }
    }

    // MARK: - Latest screenshot from Photos

    enum LatestScreenshotError: Error {
        case accessDenied, noScreenshots, loadFailed
    }

    static func latestScreenshot() async throws -> Data {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { throw LatestScreenshotError.accessDenied }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(with: .image, options: options).firstObject else {
            throw LatestScreenshotError.noScreenshots
        }

        let request = PHImageRequestOptions()
        request.isNetworkAccessAllowed = true
        request.deliveryMode = .highQualityFormat
        request.version = .current

        return try await withCheckedThrowingContinuation { cont in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: request) { data, _, _, _ in
                if let data { cont.resume(returning: data) } else { cont.resume(throwing: LatestScreenshotError.loadFailed) }
            }
        }
    }
}

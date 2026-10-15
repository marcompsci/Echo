import Foundation
import Photos
import UIKit

// MARK: - Photo Cleanup & Organizer
//
// Echo looks through your library (with your permission) and groups things
// you may not need: screenshots, screen recordings, big videos, duplicates.
// You pick what to delete. Echo asks again before deleting, and iOS shows its
// own "Delete?" prompt too. Deleted items stay in Recently Deleted for 30 days.

nonisolated struct PhotoItem: Identifiable, Hashable, Sendable {
    let id: String              // localIdentifier
    let date: Date?
    let isVideo: Bool
    let bytes: Int64
}

nonisolated enum PhotoBucket: String, CaseIterable, Identifiable, Sendable {
    case screenshots, oldScreenshots, screenRecordings, bigVideos, duplicates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenshots:      return "All screenshots"
        case .oldScreenshots:   return "Screenshots older than 30 days"
        case .screenRecordings: return "Screen recordings"
        case .bigVideos:        return "Big videos (over 100 MB)"
        case .duplicates:       return "Likely duplicates"
        }
    }

    var icon: String {
        switch self {
        case .screenshots, .oldScreenshots: return "camera.viewfinder"
        case .screenRecordings: return "record.circle"
        case .bigVideos:        return "video"
        case .duplicates:       return "square.on.square"
        }
    }

    var albumName: String {
        switch self {
        case .screenshots, .oldScreenshots: return "Screenshots (Echo)"
        case .screenRecordings: return "Screen Recordings (Echo)"
        case .bigVideos:        return "Big Videos (Echo)"
        case .duplicates:       return "Duplicates to Review (Echo)"
        }
    }
}

@Observable
@MainActor
final class PhotoCleanupModel {
    enum State: Equatable { case idle, needsAccess, scanning, ready, working(String) }

    var state: State = .idle
    var buckets: [PhotoBucket: [PhotoItem]] = [:]
    var selected: Set<String> = []
    var message: String? = nil

    var selectedBytes: Int64 {
        let all = buckets.values.flatMap { $0 }
        var seen = Set<String>(), total: Int64 = 0
        for item in all where selected.contains(item.id) && !seen.contains(item.id) {
            seen.insert(item.id); total += item.bytes
        }
        return total
    }

    func scan() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { state = .needsAccess; return }
        state = .scanning
        let result = await Task.detached(priority: .userInitiated) { Self.scanLibrary() }.value
        buckets = result
        state = .ready
    }

    nonisolated static func scanLibrary() -> [PhotoBucket: [PhotoItem]] {
        var out: [PhotoBucket: [PhotoItem]] = [:]
        let monthAgo = Date.now.addingTimeInterval(-30 * 86_400)

        func size(_ asset: PHAsset) -> Int64 {
            PHAssetResource.assetResources(for: asset).first?.value(forKey: "fileSize") as? Int64 ?? 0
        }
        func item(_ a: PHAsset) -> PhotoItem {
            PhotoItem(id: a.localIdentifier, date: a.creationDate, isVideo: a.mediaType == .video, bytes: size(a))
        }

        // Screenshots
        let shots = PHFetchOptions()
        shots.predicate = NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
        shots.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        shots.fetchLimit = 1500
        var screenshots: [PhotoItem] = []
        PHAsset.fetchAssets(with: .image, options: shots).enumerateObjects { a, _, _ in screenshots.append(item(a)) }
        out[.screenshots] = screenshots
        out[.oldScreenshots] = screenshots.filter { ($0.date ?? .now) < monthAgo }

        // Videos: screen recordings + big ones
        let vids = PHFetchOptions()
        vids.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        vids.fetchLimit = 600
        var recordings: [PhotoItem] = [], big: [PhotoItem] = []
        PHAsset.fetchAssets(with: .video, options: vids).enumerateObjects { a, _, _ in
            let resources = PHAssetResource.assetResources(for: a)
            let name = resources.first?.originalFilename.lowercased() ?? ""
            let it = item(a)
            if name.hasPrefix("rpreplay") || name.contains("screenrecording") { recordings.append(it) }
            if it.bytes > 100_000_000 { big.append(it) }
        }
        out[.screenRecordings] = recordings
        out[.bigVideos] = big.sorted { $0.bytes > $1.bytes }

        // Duplicates: same capture second + same pixel size (keeps the first of each group)
        let photos = PHFetchOptions()
        photos.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        photos.fetchLimit = 3000
        var seen: [String: Bool] = [:], dupes: [PhotoItem] = []
        PHAsset.fetchAssets(with: .image, options: photos).enumerateObjects { a, _, _ in
            guard let d = a.creationDate else { return }
            let key = "\(Int(d.timeIntervalSince1970))-\(a.pixelWidth)x\(a.pixelHeight)"
            if seen[key] != nil { dupes.append(item(a)) } else { seen[key] = true }
        }
        out[.duplicates] = dupes
        return out
    }

    func selectAll(in bucket: PhotoBucket) {
        for item in buckets[bucket] ?? [] { selected.insert(item.id) }
    }

    func clearSelection() { selected.removeAll() }

    /// Only ever called after the person confirmed in Echo AND iOS's own prompt.
    func deleteSelected() async {
        let ids = Array(selected)
        guard !ids.isEmpty else { return }
        state = .working("Deleting…")
        let bytes = selectedBytes
        do {
            try await PhotoAgent().delete(localIdentifiers: ids)
            ActivityLog.shared.record(ActivityEntry(
                batch: UUID(), summary: "Deleted \(ids.count) photo\(ids.count == 1 ? "" : "s")/video\(ids.count == 1 ? "" : "s") (\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)))",
                icon: "trash", origin: "Photo Cleanup", status: .done,
                detail: "Restore from Photos → Recently Deleted within 30 days."))
            message = "Deleted \(ids.count). You can restore them from Photos → Recently Deleted for 30 days."
            selected.removeAll()
            await scan()
        } catch {
            message = "Nothing was deleted. \(error.localizedDescription)"
            state = .ready
        }
    }

    func addSelected(toAlbum name: String) async {
        let ids = Array(selected)
        guard !ids.isEmpty else { return }
        state = .working("Organizing…")
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                let fetch = PHFetchOptions()
                fetch.predicate = NSPredicate(format: "title = %@", name)
                let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetch).firstObject
                let request = existing.flatMap { PHAssetCollectionChangeRequest(for: $0) }
                    ?? PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                request.addAssets(assets)
            }
            ActivityLog.shared.record(ActivityEntry(batch: UUID(), summary: "Added \(ids.count) items to “\(name)”",
                                                    icon: "rectangle.stack.badge.plus", origin: "Photo Cleanup", status: .done))
            message = "Added \(ids.count) to the album “\(name)”. Nothing was deleted."
            selected.removeAll()
        } catch {
            message = "Couldn't organize them: \(error.localizedDescription)"
        }
        state = .ready
    }
}

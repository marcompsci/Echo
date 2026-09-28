import Foundation
import Photos
import UIKit

// MARK: - Photo library operations using PHPhotoLibrary

actor PhotoAgent {

    // MARK: - Permission

    func requestAccess() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch current {
        case .authorized, .limited: return true
        case .denied, .restricted:  return false
        case .notDetermined:
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite) == .authorized
        @unknown default:           return false
        }
    }

    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Fetch

    struct PhotoInfo: Sendable, Identifiable {
        let id: String  // localIdentifier
        let displayName: String
        let creationDate: Date?
        let mediaType: PHAssetMediaType
        let pixelWidth: Int
        let pixelHeight: Int
        let fileSize: Int64

        var isVideo: Bool { mediaType == .video }

        var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    }

    func fetchAll(mediaType: PHAssetMediaType = .image, limit: Int = 200) async throws -> [PhotoInfo] {
        guard await requestAccess() else {
            throw EchoAgentError.permissionDenied("Photos")
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = limit

        let assets: PHFetchResult<PHAsset>
        if mediaType == .unknown {
            assets = PHAsset.fetchAssets(with: options)
        } else {
            assets = PHAsset.fetchAssets(with: mediaType, options: options)
        }

        var results: [PhotoInfo] = []
        assets.enumerateObjects { asset, _, _ in
            let resource = PHAssetResource.assetResources(for: asset).first
            let info = PhotoInfo(
                id: asset.localIdentifier,
                displayName: resource?.originalFilename ?? asset.localIdentifier,
                creationDate: asset.creationDate,
                mediaType: asset.mediaType,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                fileSize: resource?.value(forKey: "fileSize") as? Int64 ?? 0
            )
            results.append(info)
        }
        return results
    }

    func fetchScreenshots() async throws -> [PhotoInfo] {
        guard await requestAccess() else {
            throw EchoAgentError.permissionDenied("Photos")
        }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaSubtype & %d != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var results: [PhotoInfo] = []
        assets.enumerateObjects { asset, _, _ in
            let resource = PHAssetResource.assetResources(for: asset).first
            results.append(PhotoInfo(
                id: asset.localIdentifier,
                displayName: resource?.originalFilename ?? "Screenshot",
                creationDate: asset.creationDate,
                mediaType: .image,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                fileSize: resource?.value(forKey: "fileSize") as? Int64 ?? 0
            ))
        }
        return results
    }

    // MARK: - Delete

    func delete(localIdentifiers: [String]) async throws {
        guard await requestAccess() else {
            throw EchoAgentError.permissionDenied("Photos")
        }
        let assets = PHAsset.fetchAssets(
            withLocalIdentifiers: localIdentifiers,
            options: nil
        )

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    // MARK: - Create album

    func createAlbum(named name: String) async throws {
        guard await requestAccess() else {
            throw EchoAgentError.permissionDenied("Photos")
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
        }
    }

    // MARK: - Save image to library

    func saveImageData(_ data: Data) async throws {
        guard await requestAccess() else {
            throw EchoAgentError.permissionDenied("Photos")
        }
        guard let image = UIImage(data: data) else {
            throw EchoAgentError.invalidInput("Image data is not a valid image")
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

// MARK: - Agent-specific error

enum EchoAgentError: LocalizedError {
    case permissionDenied(String)
    case notFound(String)
    case invalidInput(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let what):
            return "\(what) access was denied. Enable it in Settings → Privacy."
        case .notFound(let what):
            return "\(what) could not be found."
        case .invalidInput(let msg):
            return "Invalid input: \(msg)"
        case .executionFailed(let msg):
            return "Action failed: \(msg)"
        }
    }
}

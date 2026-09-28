import Foundation
import SwiftData
import UIKit

@Observable
@MainActor
final class HomeViewModel {
    var sessions: [EchoSession] = []
    var clipboardImage: UIImage? = nil
    var isLoadingClipboard = false
    var errorMessage: String? = nil

    private let inbox = SharedImageInbox()

    func loadSessions(from context: ModelContext) {
        let descriptor = FetchDescriptor<EchoSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        sessions = (try? context.fetch(descriptor)) ?? []
    }

    func checkClipboard() {
        guard UIPasteboard.general.hasImages else {
            clipboardImage = nil
            return
        }
        clipboardImage = UIPasteboard.general.image
    }

    func consumeClipboardImage() -> Data? {
        guard let image = clipboardImage else { return nil }
        clipboardImage = nil
        return image.jpegData(compressionQuality: 0.85)
    }

    func checkForSharedImage() -> Data? {
        inbox.consumePendingImage()
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    var recentSessions: [EchoSession] {
        Array(sessions.prefix(10))
    }
}

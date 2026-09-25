import Foundation
import SwiftData

@Model
final class DebugSession {
    var id: UUID
    var timestamp: Date
    var pageURL: String
    var pageTitle: String
    var isActive: Bool

    @Relationship(deleteRule: .cascade)
    var snapshots: [ElementSnapshot]

    init(pageURL: String, pageTitle: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.pageURL = pageURL
        self.pageTitle = pageTitle
        self.isActive = true
        self.snapshots = []
    }

    var domain: String {
        URL(string: pageURL)?.host ?? pageURL
    }
}

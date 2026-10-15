import Foundation

// MARK: - Feature flags
//
// Echo deletes photos and files ONLY when you pick them yourself in Photo or
// File Cleanup and confirm. Photos also get iOS's own "Delete?" prompt and stay
// in Recently Deleted for 30 days. Voice can't delete anything directly — it
// opens Cleanup so you choose. Contacts stay off: deleting them can't be undone.
// Echo has no ability to buy or pay for anything.

nonisolated enum FeatureFlags {
    static let allowsPhotoDeletion = true      // reviewed selection + double confirmation
    static let allowsFileDeletion = true       // reviewed selection + confirmation
    static let allowsContactDeletion = false
    static let allowsPurchases = false         // never — not even with a setting

    /// Kept for older call sites: true only when both photos and contacts can be deleted.
    static var allowsPhotoAndContactDeletion: Bool { allowsPhotoDeletion && allowsContactDeletion }
}

import Foundation

// MARK: - Feature flags
//
// v1 safety: Echo never deletes photos or contacts. Voice/keyword commands are
// too easy to mishear, and these deletions are hard or impossible to undo.
// Flip to true only after the agent uses a real model + a reviewed selection UI.

nonisolated enum FeatureFlags {
    static let allowsPhotoAndContactDeletion = false
}

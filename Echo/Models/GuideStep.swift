import Foundation

struct GuideStep: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let number: Int
    let title: String
    let detail: String

    init(
        id: UUID = UUID(),
        number: Int,
        title: String,
        detail: String
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.detail = detail
    }
}

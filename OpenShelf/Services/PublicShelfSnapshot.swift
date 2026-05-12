import Foundation

struct PublicShelfSnapshot: Codable, Sendable {
    let displayName: String
    let currentlyReading: [PublicBookEntry]
    let recentlyFinished: [PublicBookEntry]
    let goalProgress: String?
    let visibilityFlags: VisibilityFlags
    let lastUpdated: Date

    struct VisibilityFlags: Codable, Sendable {
        var currentlyReading: Bool
        var recentlyFinished: Bool
        var ratings: Bool
        var goalProgress: Bool
        var notes: Bool
        var progress: Bool
    }
}

struct PublicBookEntry: Codable, Sendable, Identifiable {
    let olWorkKey: String
    let title: String
    let authorName: String
    let isbn13: String?
    let coverImageID: Int?
    let rating: Double?
    let note: String?
    let dateFinished: Date?

    var id: String { olWorkKey }
}

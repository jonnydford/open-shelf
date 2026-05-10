import Foundation
import ActivityKit

struct ReadingSessionAttributes: ActivityAttributes, Sendable {
    let olWorkKey: String
    let bookTitle: String
    let authorName: String
    let pageCount: Int?

    struct ContentState: Codable, Hashable, Sendable {
        let currentPage: Int
        let startedAt: Date
    }
}

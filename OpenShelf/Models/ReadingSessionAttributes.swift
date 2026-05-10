import Foundation
import ActivityKit

struct ReadingSessionAttributes: ActivityAttributes, Sendable {
    let olWorkKey: String
    let bookTitle: String
    let authorName: String
    let pageCount: Int?
    let isAudiobook: Bool
    let chapterCount: Int?

    init(
        olWorkKey: String,
        bookTitle: String,
        authorName: String,
        pageCount: Int?,
        isAudiobook: Bool = false,
        chapterCount: Int? = nil
    ) {
        self.olWorkKey = olWorkKey
        self.bookTitle = bookTitle
        self.authorName = authorName
        self.pageCount = pageCount
        self.isAudiobook = isAudiobook
        self.chapterCount = chapterCount
    }

    struct ContentState: Codable, Hashable, Sendable {
        let currentPage: Int
        let startedAt: Date
        let currentChapter: Int?

        init(currentPage: Int, startedAt: Date, currentChapter: Int? = nil) {
            self.currentPage = currentPage
            self.startedAt = startedAt
            self.currentChapter = currentChapter
        }
    }
}

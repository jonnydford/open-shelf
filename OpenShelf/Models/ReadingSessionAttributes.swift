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

    private enum CodingKeys: String, CodingKey {
        case olWorkKey, bookTitle, authorName, pageCount, isAudiobook, chapterCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        olWorkKey = try container.decode(String.self, forKey: .olWorkKey)
        bookTitle = try container.decode(String.self, forKey: .bookTitle)
        authorName = try container.decode(String.self, forKey: .authorName)
        pageCount = try container.decodeIfPresent(Int.self, forKey: .pageCount)
        isAudiobook = try container.decodeIfPresent(Bool.self, forKey: .isAudiobook) ?? false
        chapterCount = try container.decodeIfPresent(Int.self, forKey: .chapterCount)
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

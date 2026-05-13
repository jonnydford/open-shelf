import Foundation
import SwiftData

enum ActivityEventType: String, Codable {
    case started, finished, rated, goal
}

@Model
final class ActivityEvent {
    private static let expiryInterval: TimeInterval = 30 * 24 * 60 * 60

    var id: UUID = UUID()
    var friendDisplayName: String = ""
    var friendRecordName: String = ""
    var eventType: ActivityEventType = ActivityEventType.started
    var bookTitle: String = ""
    var bookAuthor: String = ""
    var bookCoverID: Int?
    var bookWorkKey: String?
    var rating: Double?
    var timestamp: Date = Date.now

    init(
        id: UUID = UUID(),
        friendDisplayName: String,
        friendRecordName: String,
        eventType: ActivityEventType,
        bookTitle: String,
        bookAuthor: String,
        bookCoverID: Int? = nil,
        bookWorkKey: String? = nil,
        rating: Double? = nil,
        timestamp: Date = .now
    ) {
        self.id = id
        self.friendDisplayName = friendDisplayName
        self.friendRecordName = friendRecordName
        self.eventType = eventType
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.bookCoverID = bookCoverID
        self.bookWorkKey = bookWorkKey
        self.rating = rating
        self.timestamp = timestamp
    }

    var isExpired: Bool {
        Date.now.timeIntervalSince(timestamp) > Self.expiryInterval
    }

    var asSearchResult: SearchResult? {
        guard let bookWorkKey else { return nil }
        return SearchResult(
            key: bookWorkKey,
            title: bookTitle,
            authorName: [bookAuthor],
            firstPublishYear: nil,
            numberOfPagesMedian: nil,
            coverI: bookCoverID,
            editionCount: nil,
            isbn: nil,
            subject: nil,
            idGoodreads: nil,
            ratingsAverage: nil,
            ratingsCount: nil,
            readinglogCount: nil,
            wantToReadCount: nil,
            currentlyReadingCount: nil,
            alreadyReadCount: nil,
            language: nil
        )
    }
}

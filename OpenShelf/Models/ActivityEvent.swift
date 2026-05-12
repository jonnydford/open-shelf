import Foundation
import SwiftData

@Model
final class ActivityEvent {
    var id: UUID
    var friendDisplayName: String
    var friendRecordName: String
    var eventType: String
    var bookTitle: String
    var bookAuthor: String
    var bookCoverID: Int?
    var bookWorkKey: String?
    var rating: Double?
    var timestamp: Date

    init(
        id: UUID = UUID(),
        friendDisplayName: String,
        friendRecordName: String,
        eventType: String,
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
        Date.now.timeIntervalSince(timestamp) > 30 * 24 * 60 * 60
    }
}

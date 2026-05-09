import Foundation
import SwiftData

@Model
final class Book {
    // MARK: - Identity

    @Attribute(.unique) var olWorkKey: String
    var olEditionKey: String?
    var isbn13: String?
    var isbn10: String?
    var goodreadsID: String?

    // MARK: - Cached metadata

    var title: String
    var authorName: String
    var coverImageID: Int?
    var coverCached: Bool
    var pageCount: Int?
    var firstPublishYear: Int?
    var synopsis: String?
    var subjects: [String]
    var publisher: String?
    var language: String?

    // MARK: - User data

    var shelf: Shelf
    var userRating: Double?
    var dateAdded: Date
    var dateStarted: Date?
    var dateFinished: Date?
    var currentPage: Int?
    var isFavourite: Bool
    var notes: String?
    var tags: [String]
    var queuePosition: Int?

    @Relationship(deleteRule: .cascade, inverse: \ReadEntry.book)
    var reads: [ReadEntry]

    init(
        olWorkKey: String,
        olEditionKey: String? = nil,
        isbn13: String? = nil,
        isbn10: String? = nil,
        goodreadsID: String? = nil,
        title: String,
        authorName: String,
        coverImageID: Int? = nil,
        coverCached: Bool = false,
        pageCount: Int? = nil,
        firstPublishYear: Int? = nil,
        synopsis: String? = nil,
        subjects: [String] = [],
        publisher: String? = nil,
        language: String? = nil,
        shelf: Shelf = .wantToRead,
        userRating: Double? = nil,
        dateAdded: Date = .now,
        dateStarted: Date? = nil,
        dateFinished: Date? = nil,
        currentPage: Int? = nil,
        isFavourite: Bool = false,
        notes: String? = nil,
        tags: [String] = [],
        queuePosition: Int? = nil,
        reads: [ReadEntry] = []
    ) {
        self.olWorkKey = olWorkKey
        self.olEditionKey = olEditionKey
        self.isbn13 = isbn13
        self.isbn10 = isbn10
        self.goodreadsID = goodreadsID
        self.title = title
        self.authorName = authorName
        self.coverImageID = coverImageID
        self.coverCached = coverCached
        self.pageCount = pageCount
        self.firstPublishYear = firstPublishYear
        self.synopsis = synopsis
        self.subjects = subjects
        self.publisher = publisher
        self.language = language
        self.shelf = shelf
        self.userRating = userRating
        self.dateAdded = dateAdded
        self.dateStarted = dateStarted
        self.dateFinished = dateFinished
        self.currentPage = currentPage
        self.isFavourite = isFavourite
        self.notes = notes
        self.tags = tags
        self.queuePosition = queuePosition
        self.reads = reads
    }
}

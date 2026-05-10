import Foundation
import SwiftData

// MARK: - Book Format

enum BookFormat: String, Codable, CaseIterable, Sendable {
    case book = "Book"
    case graphicNovel = "Graphic Novel"
    case manga = "Manga"
    case comic = "Comic"
    case audiobook = "Audiobook"

    static func detectFormat(subjects: [String]) -> BookFormat {
        let lower = subjects.map { $0.lowercased() }
        if lower.contains(where: { $0.contains("audiobook") || $0.contains("audiobooks") || $0.contains("audio book") }) { return .audiobook }
        if lower.contains(where: { $0.contains("manga") }) { return .manga }
        if lower.contains(where: { $0.contains("graphic novel") || $0.contains("graphic novels") }) { return .graphicNovel }
        if lower.contains(where: { $0.contains("comic") || $0.contains("comics") }) { return .comic }
        return .book
    }
}

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

    // MARK: - Privacy

    var isPrivate: Bool

    // MARK: - Series

    var seriesName: String?
    var seriesPosition: Int?

    // MARK: - Format

    var format: BookFormat

    // MARK: - Audiobook metadata

    var narrator: String?
    var durationMinutes: Int?
    var chapterCount: Int?
    var currentChapter: Int?

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
        isPrivate: Bool = false,
        seriesName: String? = nil,
        seriesPosition: Int? = nil,
        format: BookFormat = .book,
        narrator: String? = nil,
        durationMinutes: Int? = nil,
        chapterCount: Int? = nil,
        currentChapter: Int? = nil,
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
        self.isPrivate = isPrivate
        self.seriesName = seriesName
        self.seriesPosition = seriesPosition
        self.format = format
        self.narrator = narrator
        self.durationMinutes = durationMinutes
        self.chapterCount = chapterCount
        self.currentChapter = currentChapter
        self.reads = reads
    }
}

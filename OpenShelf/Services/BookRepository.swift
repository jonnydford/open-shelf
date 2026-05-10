import Foundation
import SwiftData
import Observation
import WidgetKit

@MainActor
@Observable
final class BookRepository {
    private let modelContext: ModelContext
    private let apiClient: OpenLibraryClient
    private let coverCache: CoverImageCache

    init(
        modelContext: ModelContext,
        apiClient: OpenLibraryClient = OpenLibraryClient(),
        coverCache: CoverImageCache = CoverImageCache()
    ) {
        self.modelContext = modelContext
        self.apiClient = apiClient
        self.coverCache = coverCache
    }

    // MARK: - Local operations

    func addBook(from searchResult: SearchResult, detail: WorkDetail?, shelf: Shelf) {
        let subjects = detail?.subjects ?? searchResult.subject ?? []
        let book = Book(
            olWorkKey: searchResult.key,
            isbn13: searchResult.primaryISBN13,
            isbn10: searchResult.primaryISBN10,
            goodreadsID: searchResult.primaryGoodreadsID,
            title: searchResult.title,
            authorName: searchResult.primaryAuthor,
            coverImageID: searchResult.coverI ?? detail?.primaryCoverID,
            pageCount: searchResult.numberOfPagesMedian,
            firstPublishYear: searchResult.firstPublishYear,
            synopsis: detail?.synopsis,
            subjects: subjects,
            shelf: shelf,
            dateAdded: .now,
            format: BookFormat.detectFormat(subjects: subjects)
        )

        modelContext.insert(book)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()

        // Prefetch cover in background
        if let coverID = book.coverImageID {
            Task {
                await coverCache.prefetch(coverID: coverID, size: .medium)
                book.coverCached = true
                try? self.modelContext.save()
            }
        }
    }

    func deleteBook(_ book: Book) {
        modelContext.delete(book)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateShelf(_ book: Book, to shelf: Shelf) {
        // Remove from queue when leaving want-to-read
        if shelf != .wantToRead {
            removeFromQueue(book)
        }

        book.shelf = shelf

        switch shelf {
        case .reading:
            if book.dateStarted == nil {
                book.dateStarted = .now
            }
        case .read:
            if book.dateFinished == nil {
                book.dateFinished = .now
            }
        case .wantToRead:
            book.dateStarted = nil
            book.dateFinished = nil
            book.currentPage = nil
        case .dnf:
            break
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func updateRating(_ book: Book, rating: Double?) {
        book.userRating = rating
        try? modelContext.save()
    }

    func updateProgress(_ book: Book, page: Int) {
        book.currentPage = page

        // Automatically move to "reading" if on "want to read"
        if book.shelf == .wantToRead {
            book.shelf = .reading
            book.dateStarted = .now
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func booksOnShelf(_ shelf: Shelf) -> [Book] {
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.shelf == shelf }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func allBooks() -> [Book] {
        let descriptor = FetchDescriptor<Book>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Up Next Queue

    func addToQueue(_ book: Book) {
        guard book.queuePosition == nil else { return }
        let currentMax = allQueuedBooks().map(\.queuePosition!).max() ?? -1
        book.queuePosition = currentMax + 1
        try? modelContext.save()
    }

    func removeFromQueue(_ book: Book) {
        guard book.queuePosition != nil else { return }
        book.queuePosition = nil
        // Compact remaining positions
        let remaining = allQueuedBooks().sorted { $0.queuePosition! < $1.queuePosition! }
        for (index, b) in remaining.enumerated() {
            b.queuePosition = index
        }
        try? modelContext.save()
    }

    func reorderQueue(_ books: [Book]) {
        for (index, book) in books.enumerated() {
            book.queuePosition = index
        }
        try? modelContext.save()
    }

    func nextInQueue() -> Book? {
        allQueuedBooks()
            .filter { $0.queuePosition != nil }
            .min { $0.queuePosition! < $1.queuePosition! }
    }

    func allQueuedBooks() -> [Book] {
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.queuePosition != nil }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Author Search

    nonisolated func searchByAuthor(name: String) async throws -> [SearchResult] {
        try await apiClient.searchByAuthor(name: name)
    }

    // MARK: - Import

    func importFromGoodreads(
        csv: Data,
        progressCallback: (@Sendable (Int, Int) async -> Void)? = nil
    ) async throws -> ImportResult {
        let rows = try GoodreadsImporter.parseCSV(csv)
        let total = rows.count

        // Move network-heavy work off the main actor
        let apiClient = self.apiClient
        let result: ImportResult = try await Task.detached {
            var matchedCount = 0
            var unmatchedBooks: [String] = []

            for (index, row) in rows.enumerated() {
                // Support cancellation
                try Task.checkCancellation()

                // Report progress on MainActor
                if let progressCB = progressCallback {
                    await progressCB(index + 1, total)
                }

                // Check if this book already exists
                let exists = await MainActor.run {
                    self.findExistingBook(isbn13: row.isbn13, isbn10: row.isbn, title: row.title) != nil
                }
                if exists {
                    matchedCount += 1
                    continue
                }

                // Try to match via API: ISBN13 first, then ISBN10, then title+author search
                var matchedResult: SearchResult?
                var matchedWorkDetail: WorkDetail?
                var matchedEdition: EditionDetail?

                if let isbn13 = row.isbn13 {
                    if let edition = try? await apiClient.lookupISBN(isbn13) {
                        matchedEdition = edition
                        if let workKey = edition.workKey {
                            matchedWorkDetail = try? await apiClient.fetchWorkDetail(key: workKey)
                        }
                    }
                }

                if matchedEdition == nil, let isbn = row.isbn {
                    if let edition = try? await apiClient.lookupISBN(isbn) {
                        matchedEdition = edition
                        if let workKey = edition.workKey {
                            matchedWorkDetail = try? await apiClient.fetchWorkDetail(key: workKey)
                        }
                    }
                }

                if matchedEdition == nil {
                    // Fall back to title+author search
                    let query = "\(row.title) \(row.author)"
                    let results = try? await apiClient.search(query: query)
                    if let first = results?.first {
                        matchedResult = first
                        matchedWorkDetail = try? await apiClient.fetchWorkDetail(key: first.key)
                    }
                }

                // Insert book on MainActor (SwiftData requires it)
                let matched = await MainActor.run { () -> Bool in
                    if let edition = matchedEdition {
                        let importSubjects = matchedWorkDetail?.subjects ?? []
                        let book = Book(
                            olWorkKey: edition.workKey ?? edition.key,
                            olEditionKey: edition.key,
                            isbn13: edition.primaryISBN13 ?? row.isbn13,
                            isbn10: edition.primaryISBN10 ?? row.isbn,
                            title: matchedWorkDetail?.title ?? edition.title,
                            authorName: row.author,
                            coverImageID: edition.primaryCoverID ?? matchedWorkDetail?.primaryCoverID,
                            pageCount: edition.numberOfPages ?? row.numberOfPages,
                            synopsis: matchedWorkDetail?.synopsis,
                            subjects: importSubjects,
                            publisher: edition.primaryPublisher,
                            language: edition.primaryLanguage,
                            shelf: GoodreadsImporter.mapShelf(row.bookshelf),
                            userRating: row.myRating,
                            dateAdded: row.dateAdded ?? .now,
                            dateFinished: row.dateRead,
                            notes: row.myReview,
                            format: BookFormat.detectFormat(subjects: importSubjects)
                        )
                        self.applyImportedDates(book, row: row)
                        self.modelContext.insert(book)
                        try? self.modelContext.save()
                        return true
                    } else if let result = matchedResult {
                        let importSubjects2 = matchedWorkDetail?.subjects ?? result.subject ?? []
                        let book = Book(
                            olWorkKey: result.key,
                            isbn13: result.primaryISBN13 ?? row.isbn13,
                            isbn10: result.primaryISBN10 ?? row.isbn,
                            title: result.title,
                            authorName: result.primaryAuthor,
                            coverImageID: result.coverI ?? matchedWorkDetail?.primaryCoverID,
                            pageCount: result.numberOfPagesMedian ?? row.numberOfPages,
                            firstPublishYear: result.firstPublishYear,
                            synopsis: matchedWorkDetail?.synopsis,
                            subjects: importSubjects2,
                            shelf: GoodreadsImporter.mapShelf(row.bookshelf),
                            userRating: row.myRating,
                            dateAdded: row.dateAdded ?? .now,
                            dateFinished: row.dateRead,
                            notes: row.myReview,
                            format: BookFormat.detectFormat(subjects: importSubjects2)
                        )
                        self.applyImportedDates(book, row: row)
                        self.modelContext.insert(book)
                        try? self.modelContext.save()
                        return true
                    }
                    return false
                }

                if matched {
                    matchedCount += 1
                } else {
                    unmatchedBooks.append("\(row.title) by \(row.author)")
                }

                // Rate limiting: ~3 req/sec — wait ~350ms between books
                try? await Task.sleep(for: .milliseconds(350))
            }

            return ImportResult(
                matchedCount: matchedCount,
                unmatchedCount: unmatchedBooks.count,
                errors: unmatchedBooks
            )
        }.value

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()

        return result
    }

    // MARK: - Import Helpers

    private func findExistingBook(isbn13: String?, isbn10: String?, title: String) -> Book? {
        if let isbn13 {
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate { $0.isbn13 == isbn13 }
            )
            if let existing = (try? modelContext.fetch(descriptor))?.first {
                return existing
            }
        }

        if let isbn10 {
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate { $0.isbn10 == isbn10 }
            )
            if let existing = (try? modelContext.fetch(descriptor))?.first {
                return existing
            }
        }

        // Fallback: match by title (case-insensitive) for books without ISBNs
        let lowercasedTitle = title.lowercased()
        let descriptor = FetchDescriptor<Book>()
        if let allBooks = try? modelContext.fetch(descriptor) {
            if let match = allBooks.first(where: { $0.title.lowercased() == lowercasedTitle }) {
                return match
            }
        }

        return nil
    }

    private func applyImportedDates(_ book: Book, row: GoodreadsRow) {
        let shelf = GoodreadsImporter.mapShelf(row.bookshelf)
        switch shelf {
        case .reading:
            book.dateStarted = row.dateAdded ?? .now
        case .read:
            book.dateStarted = row.dateAdded
            book.dateFinished = row.dateRead ?? row.dateAdded
        case .wantToRead, .dnf:
            break
        }
    }

    // MARK: - API operations

    nonisolated func search(query: String) async throws -> [SearchResult] {
        try await apiClient.search(query: query)
    }

    nonisolated func lookupISBN(_ isbn: String) async throws -> EditionDetail? {
        do {
            return try await apiClient.lookupISBN(isbn)
        } catch OpenLibraryError.notFound {
            return nil
        }
    }

    nonisolated func fetchDetail(for key: String) async throws -> WorkDetail {
        try await apiClient.fetchWorkDetail(key: key)
    }

    // MARK: - Author Works

    nonisolated func fetchAuthorWorks(authorKey: String, limit: Int = 5) async throws -> AuthorWorksResponse {
        try await apiClient.fetchAuthorWorks(authorKey: authorKey, limit: limit)
    }

    // MARK: - Author Detail

    nonisolated func fetchAuthorDetail(key: String) async throws -> AuthorDetail {
        try await apiClient.fetchAuthorDetail(key: key)
    }

    nonisolated func resolveWikipediaURL(wikidataID: String) async throws -> URL? {
        try await apiClient.resolveWikipediaURL(wikidataID: wikidataID)
    }

    // MARK: - Cover cache access

    nonisolated var imageCache: CoverImageCache {
        coverCache
    }
}

// MARK: - Import types

struct ImportResult: Sendable {
    let matchedCount: Int
    let unmatchedCount: Int
    let errors: [String]
}

enum ImportError: Error {
    case notImplemented
    case invalidCSV
    case parsingFailed(String)
}

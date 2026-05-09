import Foundation
import SwiftData
import Observation

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
            subjects: detail?.subjects ?? searchResult.subject ?? [],
            shelf: shelf,
            dateAdded: .now
        )

        modelContext.insert(book)
        try? modelContext.save()

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
    }

    func updateShelf(_ book: Book, to shelf: Shelf) {
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

    // MARK: - Import

    func importFromGoodreads(
        csv: Data,
        progressCallback: (@Sendable (Int, Int) async -> Void)? = nil
    ) async throws -> ImportResult {
        let rows = try GoodreadsImporter.parseCSV(csv)
        let total = rows.count
        var matchedCount = 0
        var unmatchedBooks: [String] = []

        for (index, row) in rows.enumerated() {
            // Report progress
            await progressCallback?(index + 1, total)

            // Check if this book already exists by ISBN
            let existingBook = findExistingBook(isbn13: row.isbn13, isbn10: row.isbn, title: row.title)
            if existingBook != nil {
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

            // Build the book record
            if let edition = matchedEdition {
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
                    subjects: matchedWorkDetail?.subjects ?? [],
                    publisher: edition.primaryPublisher,
                    language: edition.primaryLanguage,
                    shelf: GoodreadsImporter.mapShelf(row.bookshelf),
                    userRating: row.myRating,
                    dateAdded: row.dateAdded ?? .now,
                    dateFinished: row.dateRead,
                    notes: row.myReview
                )

                applyImportedDates(book, row: row)
                modelContext.insert(book)
                matchedCount += 1
            } else if let result = matchedResult {
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
                    subjects: matchedWorkDetail?.subjects ?? result.subject ?? [],
                    shelf: GoodreadsImporter.mapShelf(row.bookshelf),
                    userRating: row.myRating,
                    dateAdded: row.dateAdded ?? .now,
                    dateFinished: row.dateRead,
                    notes: row.myReview
                )

                applyImportedDates(book, row: row)
                modelContext.insert(book)
                matchedCount += 1
            } else {
                unmatchedBooks.append("\(row.title) by \(row.author)")
            }

            try? modelContext.save()

            // Rate limiting: ~3 req/sec — wait ~350ms between books
            try? await Task.sleep(for: .milliseconds(350))
        }

        try? modelContext.save()

        return ImportResult(
            matchedCount: matchedCount,
            unmatchedCount: unmatchedBooks.count,
            errors: unmatchedBooks
        )
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

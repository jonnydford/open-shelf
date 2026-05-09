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

    func importFromGoodreads(csv: Data) async throws -> ImportResult {
        // TODO: Implement Goodreads CSV import (issue #19, M4)
        throw ImportError.notImplemented
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

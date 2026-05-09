import Foundation
import SwiftData
import Observation

@Observable
final class BookRepository: @unchecked Sendable {
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

    @MainActor
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
                await MainActor.run {
                    book.coverCached = true
                    try? self.modelContext.save()
                }
            }
        }
    }

    @MainActor
    func deleteBook(_ book: Book) {
        modelContext.delete(book)
        try? modelContext.save()
    }

    @MainActor
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

    @MainActor
    func updateRating(_ book: Book, rating: Double?) {
        book.userRating = rating
        try? modelContext.save()
    }

    @MainActor
    func updateProgress(_ book: Book, page: Int) {
        book.currentPage = page

        // Automatically move to "reading" if on "want to read"
        if book.shelf == .wantToRead {
            book.shelf = .reading
            book.dateStarted = .now
        }

        try? modelContext.save()
    }

    // MARK: - API operations

    func search(query: String) async throws -> [SearchResult] {
        try await apiClient.search(query: query)
    }

    func lookupISBN(_ isbn: String) async throws -> EditionDetail? {
        do {
            return try await apiClient.lookupISBN(isbn)
        } catch OpenLibraryError.notFound {
            return nil
        }
    }

    func fetchDetail(for key: String) async throws -> WorkDetail {
        try await apiClient.fetchWorkDetail(key: key)
    }

    // MARK: - Cover cache access

    var imageCache: CoverImageCache {
        coverCache
    }
}

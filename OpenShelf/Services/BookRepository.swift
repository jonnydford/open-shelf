import Foundation
import SwiftData
import Observation
import WidgetKit

extension Notification.Name {
    static let publicShelfNeedsUpdate = Notification.Name("publicShelfNeedsUpdate")
}

@MainActor
@Observable
final class BookRepository {
    private let modelContext: ModelContext
    private let apiClient: OpenLibraryClient
    private let coverCache: CoverImageCache
    private let _metadataCache: MetadataCache

    init(
        modelContext: ModelContext,
        apiClient: OpenLibraryClient = OpenLibraryClient(),
        coverCache: CoverImageCache = CoverImageCache(),
        metadataCache: MetadataCache = MetadataCache()
    ) {
        self.modelContext = modelContext
        self.apiClient = apiClient
        self.coverCache = coverCache
        self._metadataCache = metadataCache
    }

    // MARK: - Reading Day Tracking

    func recordReadingDay(for date: Date = .now, bookKey: String? = nil) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<ReadingDay>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        guard (try? modelContext.fetch(descriptor))?.isEmpty ?? true else { return }
        modelContext.insert(ReadingDay(date: startOfDay, bookKey: bookKey))
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func removeReadingDay(for date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<ReadingDay>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        guard let days = try? modelContext.fetch(descriptor) else { return }
        for day in days {
            modelContext.delete(day)
        }
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func toggleReadingDay(for date: Date) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<ReadingDay>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if existing.isEmpty {
            modelContext.insert(ReadingDay(date: startOfDay))
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } else {
            for day in existing {
                modelContext.delete(day)
            }
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
            return false
        }
    }

    // MARK: - Local operations

    func existingBook(forWorkKey workKey: String) -> Book? {
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.olWorkKey == workKey }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    func existingDismissedBook(forWorkKey workKey: String) -> DismissedBook? {
        let descriptor = FetchDescriptor<DismissedBook>(
            predicate: #Predicate { $0.openLibraryWorkKey == workKey }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    func existingGoal(forYear year: Int) -> ReadingGoal? {
        let descriptor = FetchDescriptor<ReadingGoal>(
            predicate: #Predicate { $0.year == year }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    func addBook(from searchResult: SearchResult, detail: WorkDetail?, shelf: Shelf) {
        guard existingBook(forWorkKey: searchResult.key) == nil else { return }

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
            language: searchResult.primaryLanguage,
            shelf: shelf,
            dateAdded: .now,
            format: BookFormat.detectFormat(subjects: subjects)
        )

        modelContext.insert(book)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        SpotlightIndexer.indexBook(book)

        if shelf == .reading || shelf == .read {
            recordReadingDay(bookKey: book.olWorkKey)
        }

        NotificationCenter.default.post(name: .publicShelfNeedsUpdate, object: nil)

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
        SpotlightIndexer.removeBook(book)
        modelContext.delete(book)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .publicShelfNeedsUpdate, object: nil)
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
            book.currentChapter = nil
        case .dnf:
            break
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        SpotlightIndexer.indexBook(book)

        if shelf == .reading || shelf == .read {
            recordReadingDay(bookKey: book.olWorkKey)
        }

        NotificationCenter.default.post(name: .publicShelfNeedsUpdate, object: nil)
    }

    func updateRating(_ book: Book, rating: Double?) {
        book.userRating = rating
        book.latestRead?.rating = rating
        try? modelContext.save()
        NotificationCenter.default.post(name: .publicShelfNeedsUpdate, object: nil)
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
        recordReadingDay(bookKey: book.olWorkKey)
    }

    func updateChapterProgress(_ book: Book, chapter: Int) {
        book.currentChapter = chapter

        // Automatically move to "reading" if on "want to read"
        if book.shelf == .wantToRead {
            book.shelf = .reading
            book.dateStarted = .now
        }

        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()
        recordReadingDay(bookKey: book.olWorkKey)
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

    // MARK: - Public Shelf Snapshot

    func buildPublicShelfSnapshot(
        displayName: String,
        flags: PublicShelfSnapshot.VisibilityFlags
    ) -> PublicShelfSnapshot {
        let allBooks = allBooks().filter { !$0.isPrivate }

        let currentlyReading: [PublicBookEntry] = flags.currentlyReading
            ? allBooks.filter { $0.shelf == .reading }.map { book in
                PublicBookEntry(
                    olWorkKey: book.olWorkKey,
                    title: book.title,
                    authorName: book.authorName,
                    isbn13: book.isbn13,
                    coverImageID: book.coverImageID,
                    rating: flags.ratings ? book.userRating : nil,
                    note: flags.notes ? book.notes.map { String($0.prefix(200)) } : nil,
                    dateFinished: nil
                )
            }
            : []

        let recentlyFinished: [PublicBookEntry] = flags.recentlyFinished
            ? allBooks
                .filter { $0.shelf == .read }
                .sorted { ($0.dateFinished ?? .distantPast) > ($1.dateFinished ?? .distantPast) }
                .prefix(10)
                .map { book in
                    PublicBookEntry(
                        olWorkKey: book.olWorkKey,
                        title: book.title,
                        authorName: book.authorName,
                        isbn13: book.isbn13,
                        coverImageID: book.coverImageID,
                        rating: flags.ratings ? book.userRating : nil,
                        note: flags.notes ? book.notes.map { String($0.prefix(200)) } : nil,
                        dateFinished: book.dateFinished
                    )
                }
            : []

        var goalProgress: String?
        if flags.goalProgress {
            let year = Calendar.current.component(.year, from: .now)
            let descriptor = FetchDescriptor<ReadingGoal>(
                predicate: #Predicate { $0.year == year }
            )
            if let goal = (try? modelContext.fetch(descriptor))?.first {
                let readCount = allBooks.filter {
                    $0.shelf == .read &&
                    $0.dateFinished.map { Calendar.current.component(.year, from: $0) == year } ?? false
                }.count
                goalProgress = "\(readCount)/\(goal.target)"
            }
        }

        return PublicShelfSnapshot(
            displayName: displayName,
            currentlyReading: currentlyReading,
            recentlyFinished: recentlyFinished,
            goalProgress: goalProgress,
            visibilityFlags: flags,
            lastUpdated: .now
        )
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

    nonisolated func searchByAuthor(name: String, languages: [String]? = nil) async throws -> [SearchResult] {
        try await apiClient.searchByAuthor(name: name, languages: languages)
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
                        let workKey = edition.workKey ?? edition.key
                        guard self.existingBook(forWorkKey: workKey) == nil else { return true }
                        let importSubjects = matchedWorkDetail?.subjects ?? []
                        let book = Book(
                            olWorkKey: workKey,
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
                        guard self.existingBook(forWorkKey: result.key) == nil else { return true }
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
            let started = row.dateAdded ?? .now
            book.dateStarted = started
            recordReadingDay(for: started, bookKey: book.olWorkKey)
        case .read:
            book.dateStarted = row.dateAdded
            let finished = row.dateRead ?? row.dateAdded ?? .now
            book.dateFinished = finished
            if let started = row.dateAdded {
                recordReadingDay(for: started, bookKey: book.olWorkKey)
            }
            recordReadingDay(for: finished, bookKey: book.olWorkKey)
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

    nonisolated func fetchDetail(for key: String, forceRefresh: Bool = false) async throws -> WorkDetail {
        if forceRefresh {
            let detail = try await apiClient.fetchWorkDetail(key: key)
            await metadataCache.set(detail, for: key, ttl: 24 * 60 * 60)
            return detail
        }
        if let cached = await metadataCache.cachedWork(for: key, fetch: { [apiClient] in
            try await apiClient.fetchWorkDetail(key: key)
        }) {
            return cached
        }
        throw OpenLibraryError.networkError(URLError(.notConnectedToInternet))
    }

    // MARK: - Author Works

    nonisolated func fetchAuthorWorks(authorKey: String, limit: Int = 5) async throws -> AuthorWorksResponse {
        try await apiClient.fetchAuthorWorks(authorKey: authorKey, limit: limit)
    }

    // MARK: - Subjects

    nonisolated func fetchSubject(_ slug: String, limit: Int = 20, languages: [String]? = nil) async throws -> SubjectResponse {
        try await apiClient.fetchSubject(slug, limit: limit, languages: languages)
    }

    // MARK: - Popular by Subject

    nonisolated func searchPopular(subject: String, limit: Int = 10, languages: [String]? = nil) async throws -> [SearchResult] {
        try await apiClient.searchPopular(subject: subject, limit: limit, languages: languages)
    }

    // MARK: - Ratings & Bookshelves

    nonisolated func fetchRatings(workKey: String) async throws -> WorkRatings {
        try await apiClient.fetchRatings(workKey: workKey)
    }

    nonisolated func fetchBookshelves(workKey: String) async throws -> WorkBookshelves {
        try await apiClient.fetchBookshelves(workKey: workKey)
    }

    // MARK: - Author Detail

    nonisolated func fetchAuthorDetail(key: String, forceRefresh: Bool = false) async throws -> AuthorDetail {
        if forceRefresh {
            let detail = try await apiClient.fetchAuthorDetail(key: key)
            await metadataCache.set(detail, for: key, ttl: 7 * 24 * 60 * 60)
            return detail
        }
        if let cached = await metadataCache.cachedAuthor(for: key, fetch: { [apiClient] in
            try await apiClient.fetchAuthorDetail(key: key)
        }) {
            return cached
        }
        throw OpenLibraryError.networkError(URLError(.notConnectedToInternet))
    }

    nonisolated func resolveWikipediaURL(wikidataID: String, forceRefresh: Bool = false) async throws -> URL? {
        let cacheKey = "wikipedia_\(wikidataID)"
        if !forceRefresh, let cached: CachedURL = await metadataCache.get(CachedURL.self, for: cacheKey) {
            return cached.url
        }
        let url = try await apiClient.resolveWikipediaURL(wikidataID: wikidataID)
        await metadataCache.set(CachedURL(url: url), for: cacheKey, ttl: 7 * 24 * 60 * 60)
        return url
    }

    // MARK: - Apple Books

    nonisolated func fetchAppleBooksLink(isbn: String) async -> ITunesEbook? {
        let cacheKey = "apple_books_\(isbn)"
        if let cached: ITunesEbook = await metadataCache.get(ITunesEbook.self, for: cacheKey) {
            return cached
        }
        let result = await apiClient.fetchAppleBooksLink(isbn: isbn)
        if let result {
            await metadataCache.set(result, for: cacheKey, ttl: 24 * 60 * 60)
        }
        return result
    }

    // MARK: - Cover cache access

    nonisolated var imageCache: CoverImageCache {
        coverCache
    }

    nonisolated var metadataCache: MetadataCache {
        _metadataCache
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

private struct CachedURL: Codable, Sendable {
    let url: URL?
}

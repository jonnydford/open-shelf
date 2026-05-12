import Foundation
import SwiftData

struct DiscoverRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let books: [SearchResult]
}

@MainActor
@Observable
final class DiscoverRecommendationService {
    private(set) var recommendations: [DiscoverRecommendation] = []
    private(set) var isLoading = false

    private var lastRefresh: Date?
    private static let cooldown: TimeInterval = 5 * 60

    func refreshIfNeeded(
        library: [Book],
        dismissed: [DismissedBook],
        using repository: BookRepository
    ) async {
        if let last = lastRefresh, Date.now.timeIntervalSince(last) < Self.cooldown {
            return
        }

        let readBooks = library.filter { $0.shelf == .read }
        guard readBooks.count >= 3 else {
            recommendations = []
            return
        }

        isLoading = true
        defer {
            isLoading = false
            lastRefresh = .now
        }

        let libraryKeys = Set(library.map(\.olWorkKey))
        let dismissedKeys = Set(dismissed.map(\.openLibraryWorkKey))
        let excludeKeys = libraryKeys.union(dismissedKeys)

        let authorRec = await generateAuthorRecommendation(
            readBooks: readBooks,
            excludeKeys: excludeKeys,
            using: repository
        )
        let subjectRec = await generateSubjectRecommendation(
            readBooks: readBooks,
            excludeKeys: excludeKeys,
            using: repository
        )
        let genreRec = await generateGenreRecommendation(
            readBooks: readBooks,
            excludeKeys: excludeKeys,
            using: repository
        )

        recommendations = [authorRec, subjectRec, genreRec].compactMap { $0 }
    }

    // MARK: - "More from [Author]"

    private func generateAuthorRecommendation(
        readBooks: [Book],
        excludeKeys: Set<String>,
        using repository: BookRepository
    ) async -> DiscoverRecommendation? {
        var authorCounts: [String: Int] = [:]
        for book in readBooks {
            authorCounts[book.authorName, default: 0] += 1
        }

        guard let topAuthor = authorCounts
            .filter({ $0.value >= 2 })
            .max(by: { $0.value < $1.value })?
            .key else {
            return nil
        }

        do {
            let results = try await repository.searchByAuthor(name: topAuthor)
            let filtered = results.filter { !excludeKeys.contains($0.key) }
            guard !filtered.isEmpty else { return nil }
            return DiscoverRecommendation(
                title: "More from \(topAuthor)",
                subtitle: "You've read \(authorCounts[topAuthor]!) of their books",
                books: Array(filtered.prefix(10))
            )
        } catch {
            return nil
        }
    }

    // MARK: - "Because you read [Book]"

    private func generateSubjectRecommendation(
        readBooks: [Book],
        excludeKeys: Set<String>,
        using repository: BookRepository
    ) async -> DiscoverRecommendation? {
        guard let recentBook = readBooks
            .sorted(by: { ($0.dateFinished ?? .distantPast) > ($1.dateFinished ?? .distantPast) })
            .first,
              let topSubject = recentBook.subjects.first else {
            return nil
        }

        do {
            let response = try await repository.fetchSubject(topSubject, limit: 20)
            let filtered = response.works
                .map(\.asSearchResult)
                .filter { !excludeKeys.contains($0.key) }
            guard !filtered.isEmpty else { return nil }
            return DiscoverRecommendation(
                title: "Because you read \(recentBook.title)",
                subtitle: "More in \(topSubject)",
                books: Array(filtered.prefix(10))
            )
        } catch {
            return nil
        }
    }

    // MARK: - "Popular in [Genre]"

    private func generateGenreRecommendation(
        readBooks: [Book],
        excludeKeys: Set<String>,
        using repository: BookRepository
    ) async -> DiscoverRecommendation? {
        var genreCounts: [String: Int] = [:]
        for book in readBooks {
            let genre = StatsCalculator.classifyGenre(subjects: book.subjects)
            if genre != "Other" {
                genreCounts[genre, default: 0] += 1
            }
        }

        guard let topGenre = genreCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        do {
            let response = try await repository.fetchSubject(topGenre, limit: 20)
            let filtered = response.works
                .map(\.asSearchResult)
                .filter { !excludeKeys.contains($0.key) }
            guard !filtered.isEmpty else { return nil }
            return DiscoverRecommendation(
                title: "Popular in \(topGenre)",
                subtitle: "Based on your reading history",
                books: Array(filtered.prefix(10))
            )
        } catch {
            return nil
        }
    }
}

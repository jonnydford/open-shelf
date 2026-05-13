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
        languages: [String],
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

        let libraryKeys = Set(library.map(\.olWorkKey))
        let dismissedKeys = Set(dismissed.map(\.openLibraryWorkKey))
        let excludeKeys = libraryKeys.union(dismissedKeys)

        let authorRec = await generateAuthorRecommendation(
            readBooks: readBooks,
            excludeKeys: excludeKeys,
            languages: languages,
            using: repository
        )
        let subjectRec = await generateSubjectRecommendation(
            readBooks: readBooks,
            excludeKeys: excludeKeys,
            languages: languages,
            using: repository
        )
        let genreRec = await generateGenreRecommendation(
            readBooks: readBooks,
            excludeKeys: excludeKeys,
            languages: languages,
            using: repository
        )

        let results = [authorRec, subjectRec, genreRec].compactMap { $0 }
        recommendations = results
        isLoading = false
        if !results.isEmpty {
            lastRefresh = .now
        }
    }

    // MARK: - "More from [Author]"

    private func generateAuthorRecommendation(
        readBooks: [Book],
        excludeKeys: Set<String>,
        languages: [String],
        using repository: BookRepository
    ) async -> DiscoverRecommendation? {
        var authorCounts: [String: Int] = [:]
        for book in readBooks {
            authorCounts[book.authorName, default: 0] += 1
        }

        guard let top = authorCounts
            .filter({ $0.value >= 2 })
            .max(by: { $0.value < $1.value }) else {
            return nil
        }

        do {
            let results = try await repository.searchByAuthor(name: top.key, languages: languages)
            let filtered = results.filter { !excludeKeys.contains($0.key) }
            guard !filtered.isEmpty else { return nil }
            return DiscoverRecommendation(
                title: "More from \(top.key)",
                subtitle: "You've read \(top.value) of their books",
                books: Array(filtered.prefix(10))
            )
        } catch {
            return nil
        }
    }

    // MARK: - "Because you read [Book]"

    private static let genericSubjects: Set<String> = [
        "fiction", "nonfiction", "non-fiction", "literature", "novels",
        "classic literature", "books", "reading"
    ]

    private func generateSubjectRecommendation(
        readBooks: [Book],
        excludeKeys: Set<String>,
        languages: [String],
        using repository: BookRepository
    ) async -> DiscoverRecommendation? {
        let dated = readBooks.filter { $0.dateFinished != nil }
        let candidates = dated.isEmpty ? readBooks : dated

        guard let recentBook = candidates
            .sorted(by: { ($0.dateFinished ?? .distantPast) > ($1.dateFinished ?? .distantPast) })
            .first else {
            return nil
        }

        let topSubject = recentBook.subjects
            .first { !Self.genericSubjects.contains($0.lowercased()) }
            ?? recentBook.subjects.first

        guard let topSubject else { return nil }

        do {
            let response = try await repository.fetchSubject(topSubject, limit: 20, languages: languages)
            let filtered = response.works
                .map(\.asSearchResult)
                .filter { !excludeKeys.contains($0.key) }
            guard !filtered.isEmpty else { return nil }
            return DiscoverRecommendation(
                title: "Because you read \(recentBook.title)",
                subtitle: "More in \(topSubject.capitalized)",
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
        languages: [String],
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
            let response = try await repository.fetchSubject(topGenre, limit: 20, languages: languages)
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

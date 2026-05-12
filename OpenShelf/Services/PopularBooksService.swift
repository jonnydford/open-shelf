import Foundation
import os

struct PopularGenreSection: Identifiable, Sendable {
    let id: String
    let genre: String
    let books: [SearchResult]
}

private let popularBooksLogger = Logger(subsystem: "com.forddevinc.OpenShelf", category: "PopularBooks")

private let popularGenres: [(slug: String, displayName: String)] = [
    ("fiction", "Fiction"),
    ("science_fiction", "Science Fiction"),
    ("mystery", "Mystery"),
    ("romance", "Romance"),
    ("fantasy", "Fantasy"),
]

@MainActor
@Observable
final class PopularBooksService {
    private(set) var sections: [PopularGenreSection] = []
    private(set) var isLoading = false

    private var lastRefresh: Date?
    private static let cooldown: TimeInterval = 60 * 60

    func refreshIfNeeded(
        libraryKeys: Set<String>,
        dismissedKeys: Set<String>,
        genreCounts: [String: Int],
        using repository: BookRepository
    ) async {
        guard !isLoading else { return }

        if let last = lastRefresh, Date.now.timeIntervalSince(last) < Self.cooldown {
            return
        }

        isLoading = true
        defer { isLoading = false }

        let excludeKeys = libraryKeys.union(dismissedKeys)
        let sorted = Self.sortedGenres(by: genreCounts)

        let results = await withTaskGroup(
            of: PopularGenreSection?.self,
            returning: [PopularGenreSection].self
        ) { group in
            for genre in sorted {
                group.addTask {
                    await Self.fetchGenre(
                        slug: genre.slug,
                        displayName: genre.displayName,
                        excludeKeys: excludeKeys,
                        using: repository
                    )
                }
            }

            var collected: [PopularGenreSection] = []
            for await section in group {
                if let section { collected.append(section) }
            }
            return collected
        }

        let slugOrder = sorted.map(\.slug)
        let orderedResults = slugOrder.compactMap { slug in
            results.first { $0.id == slug }
        }
        var seenKeys = Set<String>()
        var deduplicated: [PopularGenreSection] = []
        for section in orderedResults {
            let uniqueBooks = section.books.filter { seenKeys.insert($0.key).inserted }
            guard !uniqueBooks.isEmpty else { continue }
            deduplicated.append(PopularGenreSection(
                id: section.id,
                genre: section.genre,
                books: uniqueBooks
            ))
        }

        sections = deduplicated
        if !deduplicated.isEmpty {
            lastRefresh = .now
        }
    }

    private static let genreNameToSlug: [String: String] = [
        "Fiction": "fiction",
        "Science Fiction": "science_fiction",
        "Mystery": "mystery",
        "Romance": "romance",
        "Fantasy": "fantasy",
    ]

    private static func sortedGenres(
        by genreCounts: [String: Int]
    ) -> [(slug: String, displayName: String)] {
        let slugCounts: [String: Int] = genreCounts.reduce(into: [:]) { result, pair in
            if let slug = genreNameToSlug[pair.key] {
                result[slug, default: 0] += pair.value
            }
        }

        return popularGenres.sorted { a, b in
            let countA = slugCounts[a.slug] ?? 0
            let countB = slugCounts[b.slug] ?? 0
            if countA != countB { return countA > countB }
            return false
        }
    }

    private static nonisolated func fetchGenre(
        slug: String,
        displayName: String,
        excludeKeys: Set<String>,
        using repository: BookRepository
    ) async -> PopularGenreSection? {
        do {
            let results = try await repository.searchPopular(subject: slug, limit: 15)
            let filtered = results.filter { !excludeKeys.contains($0.key) && $0.coverI != nil }
            guard !filtered.isEmpty else { return nil }
            return PopularGenreSection(
                id: slug,
                genre: displayName,
                books: Array(filtered.prefix(10))
            )
        } catch {
            popularBooksLogger.error("Failed to fetch popular \(slug, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

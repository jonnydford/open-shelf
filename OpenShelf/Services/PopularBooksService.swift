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
    private var lastLanguages: [String]?
    private static let cooldown: TimeInterval = 60 * 60

    func refreshIfNeeded(
        libraryKeys: Set<String>,
        dismissedKeys: Set<String>,
        genreCounts: [String: Int],
        languages: [String],
        using repository: BookRepository
    ) async {
        guard !isLoading else { return }

        let languagesChanged = lastLanguages != languages
        if let last = lastRefresh, Date.now.timeIntervalSince(last) < Self.cooldown, !languagesChanged {
            return
        }

        isLoading = true
        defer { isLoading = false }
        lastLanguages = languages

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
                        languages: languages,
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

    private static let genreNameToSlug: [String: String] = {
        var mapping = Dictionary(uniqueKeysWithValues: popularGenres.map { ($0.displayName, $0.slug) })
        mapping["Thriller"] = "mystery"
        mapping["Historical Fiction"] = "fiction"
        mapping["Literary Fiction"] = "fiction"
        mapping["Horror"] = "fantasy"
        mapping["Non-Fiction"] = "fiction"
        return mapping
    }()

    private static let slugIndex: [String: Int] = Dictionary(
        uniqueKeysWithValues: popularGenres.enumerated().map { ($1.slug, $0) }
    )

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
            return (slugIndex[a.slug] ?? 0) < (slugIndex[b.slug] ?? 0)
        }
    }

    private static nonisolated func fetchGenre(
        slug: String,
        displayName: String,
        excludeKeys: Set<String>,
        languages: [String],
        using repository: BookRepository
    ) async -> PopularGenreSection? {
        do {
            let results = try await repository.searchPopular(subject: slug, limit: 15, languages: languages)
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

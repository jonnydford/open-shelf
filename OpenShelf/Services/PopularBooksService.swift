import Foundation

struct PopularGenreSection: Identifiable {
    let id: String
    let genre: String
    let books: [SearchResult]
}

@MainActor
@Observable
final class PopularBooksService {
    private(set) var sections: [PopularGenreSection] = []
    private(set) var isLoading = false

    private var lastRefresh: Date?
    private static let cooldown: TimeInterval = 60 * 60

    private static let genres = [
        "fiction",
        "science_fiction",
        "mystery",
        "romance",
        "fantasy",
        "biography",
        "history",
        "thriller",
        "horror",
        "self-help",
    ]

    private static let genreDisplayNames: [String: String] = [
        "fiction": "Fiction",
        "science_fiction": "Science Fiction",
        "mystery": "Mystery",
        "romance": "Romance",
        "fantasy": "Fantasy",
        "biography": "Biography",
        "history": "History",
        "thriller": "Thriller",
        "horror": "Horror",
        "self-help": "Self-Help",
    ]

    func refreshIfNeeded(
        libraryKeys: Set<String>,
        dismissedKeys: Set<String>,
        using repository: BookRepository
    ) async {
        if let last = lastRefresh, Date.now.timeIntervalSince(last) < Self.cooldown {
            return
        }

        isLoading = true

        let excludeKeys = libraryKeys.union(dismissedKeys)
        var results: [PopularGenreSection] = []

        for genre in Self.genres {
            guard let section = await fetchGenre(
                genre,
                excludeKeys: excludeKeys,
                using: repository
            ) else { continue }
            results.append(section)
        }

        sections = results
        isLoading = false
        if !results.isEmpty {
            lastRefresh = .now
        }
    }

    private func fetchGenre(
        _ genre: String,
        excludeKeys: Set<String>,
        using repository: BookRepository
    ) async -> PopularGenreSection? {
        do {
            let results = try await repository.searchPopular(subject: genre, limit: 15)
            let filtered = results.filter { !excludeKeys.contains($0.key) && $0.coverI != nil }
            guard !filtered.isEmpty else { return nil }
            let displayName = Self.genreDisplayNames[genre] ?? genre.capitalized
            return PopularGenreSection(
                id: genre,
                genre: displayName,
                books: Array(filtered.prefix(10))
            )
        } catch {
            return nil
        }
    }
}

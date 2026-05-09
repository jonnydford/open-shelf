import Foundation

@MainActor
struct RecommendationEngine {

    /// Score each library book by similarity to the given book.
    /// Weights: same author (50pts), genre overlap (30pts per shared genre),
    /// page count within 20% (10pts), both rated >= 4 (10pts).
    /// Excludes the book itself and books on the .reading shelf.
    static func similarBooks(to book: Book, from library: [Book], limit: Int = 5) -> [Book] {
        let candidates = library.filter { $0.olWorkKey != book.olWorkKey && $0.shelf != .reading }

        let scored = candidates.map { candidate -> (Book, Int) in
            var score = 0

            // Same author: 50 points
            if candidate.authorName.lowercased() == book.authorName.lowercased() {
                score += 50
            }

            // Genre (subject) overlap: 30 points per shared genre
            let bookSubjects = Set(book.subjects.map { $0.lowercased() })
            let candidateSubjects = Set(candidate.subjects.map { $0.lowercased() })
            let sharedGenres = bookSubjects.intersection(candidateSubjects).count
            score += sharedGenres * 30

            // Page count within 20%: 10 points
            if let bookPages = book.pageCount, let candidatePages = candidate.pageCount,
               bookPages > 0 {
                let ratio = Double(candidatePages) / Double(bookPages)
                if ratio >= 0.8 && ratio <= 1.2 {
                    score += 10
                }
            }

            // Both rated >= 4: 10 points
            if let bookRating = book.userRating, let candidateRating = candidate.userRating,
               bookRating >= 4, candidateRating >= 4 {
                score += 10
            }

            return (candidate, score)
        }

        return scored
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    /// Find want-to-read books that match patterns from the user's highest-rated books.
    /// Looks at genres and authors from top-rated books and scores want-to-read candidates.
    static func recommendedForYou(from library: [Book], limit: Int = 5) -> [Book] {
        // Find the user's top-rated books (rated >= 4)
        let topRated = library.filter { ($0.userRating ?? 0) >= 4 }
        guard !topRated.isEmpty else { return [] }

        // Collect favourite authors and genres
        var authorScores: [String: Int] = [:]
        var genreScores: [String: Int] = [:]

        for book in topRated {
            let authorKey = book.authorName.lowercased()
            authorScores[authorKey, default: 0] += 1

            for subject in book.subjects {
                genreScores[subject.lowercased(), default: 0] += 1
            }
        }

        // Score want-to-read books
        let candidates = library.filter { $0.shelf == .wantToRead }

        let scored = candidates.map { candidate -> (Book, Int) in
            var score = 0

            let authorKey = candidate.authorName.lowercased()
            if let authorCount = authorScores[authorKey] {
                score += authorCount * 50
            }

            for subject in candidate.subjects {
                if let genreCount = genreScores[subject.lowercased()] {
                    score += genreCount * 30
                }
            }

            return (candidate, score)
        }

        return scored
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }
}

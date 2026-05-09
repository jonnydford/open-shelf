import Foundation

struct Badge: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let isUnlocked: Bool
}

@MainActor
struct BadgeEngine {

    static let totalBadgeCount = 9

    static func evaluateBadges(books: [Book], streak: Int, goalMet: Bool) -> [Badge] {
        let readBooks = books.filter { $0.shelf == .read }
        let readCount = readBooks.count

        return [
            firstBookBadge(readCount: readCount),
            bookwormBadge(readCount: readCount),
            centurionBadge(readCount: readCount),
            speedReaderBadge(readBooks: readBooks),
            marathonReaderBadge(readBooks: readBooks),
            genreExplorerBadge(readBooks: readBooks),
            loyalFanBadge(readBooks: readBooks),
            streakMasterBadge(streak: streak),
            goalCrusherBadge(goalMet: goalMet),
        ]
    }

    // MARK: - Individual Badges

    private static func firstBookBadge(readCount: Int) -> Badge {
        Badge(
            id: "first_book",
            title: "First Book",
            description: "Finish your first book",
            icon: "book.closed.fill",
            isUnlocked: readCount >= 1
        )
    }

    private static func bookwormBadge(readCount: Int) -> Badge {
        Badge(
            id: "bookworm",
            title: "Bookworm",
            description: "Read 10 books",
            icon: "books.vertical.fill",
            isUnlocked: readCount >= 10
        )
    }

    private static func centurionBadge(readCount: Int) -> Badge {
        Badge(
            id: "centurion",
            title: "Centurion",
            description: "Read 100 books",
            icon: "star.circle.fill",
            isUnlocked: readCount >= 100
        )
    }

    private static func speedReaderBadge(readBooks: [Book]) -> Badge {
        let calendar = Calendar.current
        let hasSpeedRead = readBooks.contains { book in
            guard let start = book.dateStarted, let finish = book.dateFinished else { return false }
            let days = calendar.dateComponents([.day], from: start, to: finish).day ?? 0
            return days < 3
        }
        return Badge(
            id: "speed_reader",
            title: "Speed Reader",
            description: "Finish a book in under 3 days",
            icon: "hare.fill",
            isUnlocked: hasSpeedRead
        )
    }

    private static func marathonReaderBadge(readBooks: [Book]) -> Badge {
        let hasMarathon = readBooks.contains { ($0.pageCount ?? 0) > 500 }
        return Badge(
            id: "marathon_reader",
            title: "Marathon Reader",
            description: "Finish a book over 500 pages",
            icon: "figure.walk",
            isUnlocked: hasMarathon
        )
    }

    private static func genreExplorerBadge(readBooks: [Book]) -> Badge {
        let genres = Set(readBooks.map { StatsCalculator.classifyGenre(subjects: $0.subjects) })
        return Badge(
            id: "genre_explorer",
            title: "Genre Explorer",
            description: "Read books in 5+ genres",
            icon: "globe",
            isUnlocked: genres.count >= 5
        )
    }

    private static func loyalFanBadge(readBooks: [Book]) -> Badge {
        var authorCounts = [String: Int]()
        for book in readBooks {
            let author = book.authorName.lowercased()
            authorCounts[author, default: 0] += 1
        }
        let hasLoyalFan = authorCounts.values.contains { $0 >= 3 }
        return Badge(
            id: "loyal_fan",
            title: "Loyal Fan",
            description: "Read 3+ books by the same author",
            icon: "heart.fill",
            isUnlocked: hasLoyalFan
        )
    }

    private static func streakMasterBadge(streak: Int) -> Badge {
        Badge(
            id: "streak_master",
            title: "Streak Master",
            description: "Maintain a 30-day reading streak",
            icon: "flame.fill",
            isUnlocked: streak >= 30
        )
    }

    private static func goalCrusherBadge(goalMet: Bool) -> Badge {
        Badge(
            id: "goal_crusher",
            title: "Goal Crusher",
            description: "Hit your annual reading goal",
            icon: "trophy.fill",
            isUnlocked: goalMet
        )
    }
}

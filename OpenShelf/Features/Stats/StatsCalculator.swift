import Foundation

enum YearFilter: Hashable {
    case year(Int)
    case allTime

    var displayName: String {
        switch self {
        case .year(let y): String(y)
        case .allTime: "All Time"
        }
    }
}

@MainActor
struct StatsCalculator {

    // MARK: - Filtering

    static func booksRead(from books: [Book], filter: YearFilter) -> [Book] {
        let readBooks = books.filter { $0.shelf == .read }
        switch filter {
        case .year(let year):
            return readBooks.filter { finishedInYear($0, year: year) }
        case .allTime:
            return readBooks
        }
    }

    static func dnfBooks(from books: [Book], filter: YearFilter) -> [Book] {
        let dnf = books.filter { $0.shelf == .dnf }
        switch filter {
        case .year(let year):
            return dnf.filter {
                guard let date = $0.dateFinished ?? $0.dateStarted else { return false }
                return Calendar.current.component(.year, from: date) == year
            }
        case .allTime:
            return dnf
        }
    }

    // MARK: - Summary

    static func totalPages(_ books: [Book]) -> Int {
        books.compactMap(\.pageCount).reduce(0, +)
    }

    static func averageRating(_ books: [Book]) -> Double? {
        let ratings = books.compactMap(\.userRating).filter { $0 > 0 }
        guard !ratings.isEmpty else { return nil }
        return ratings.reduce(0, +) / Double(ratings.count)
    }

    // MARK: - Books per month

    struct MonthCount: Identifiable {
        let month: Int
        let count: Int
        var id: Int { month }

        var monthName: String {
            Calendar.current.shortMonthSymbols[month - 1]
        }
    }

    static func booksPerMonth(_ books: [Book]) -> [MonthCount] {
        var counts = [Int: Int]()
        for book in books {
            if let date = book.dateFinished {
                let month = Calendar.current.component(.month, from: date)
                counts[month, default: 0] += 1
            }
        }
        return (1...12).map { MonthCount(month: $0, count: counts[$0, default: 0]) }
    }

    // MARK: - Pages per month

    struct MonthPages: Identifiable {
        let month: Int
        let pages: Int
        var id: Int { month }

        var monthName: String {
            Calendar.current.shortMonthSymbols[month - 1]
        }
    }

    static func pagesPerMonth(_ books: [Book]) -> [MonthPages] {
        var pages = [Int: Int]()
        for book in books {
            if let date = book.dateFinished, let pc = book.pageCount {
                let month = Calendar.current.component(.month, from: date)
                pages[month, default: 0] += pc
            }
        }
        return (1...12).map { MonthPages(month: $0, pages: pages[$0, default: 0]) }
    }

    // MARK: - Books per year (for all-time view)

    struct YearCount: Identifiable {
        let year: Int
        let count: Int
        var id: Int { year }
    }

    static func booksPerYear(_ books: [Book]) -> [YearCount] {
        var counts = [Int: Int]()
        for book in books {
            if let date = book.dateFinished {
                let year = Calendar.current.component(.year, from: date)
                counts[year, default: 0] += 1
            }
        }
        return counts.keys.sorted().map { YearCount(year: $0, count: counts[$0, default: 0]) }
    }

    // MARK: - Genre breakdown

    static let genreKeywords: [(genre: String, keywords: [String])] = [
        ("Science Fiction", ["science fiction", "sci-fi", "science_fiction", "scifi"]),
        ("Historical Fiction", ["historical fiction", "historical_fiction"]),
        ("Literary Fiction", ["literary fiction", "literary_fiction"]),
        ("Fantasy", ["fantasy"]),
        ("Mystery", ["mystery", "detective"]),
        ("Romance", ["romance"]),
        ("Thriller", ["thriller", "suspense"]),
        ("Horror", ["horror"]),
        ("Biography", ["biography", "autobiography", "memoir"]),
        ("Self-Help", ["self-help", "self_help", "personal development"]),
        ("Science", ["science", "physics", "chemistry", "biology", "mathematics"]),
        ("History", ["history"]),
        ("Poetry", ["poetry", "poems"]),
        ("Non-Fiction", ["non-fiction", "nonfiction", "non_fiction"]),
        ("Fiction", ["fiction"]),
    ]

    struct GenreCount: Identifiable {
        let genre: String
        let count: Int
        var id: String { genre }
    }

    static func genreBreakdown(_ books: [Book]) -> [GenreCount] {
        var counts = [String: Int]()

        for book in books {
            let genre = classifyGenre(subjects: book.subjects)
            counts[genre, default: 0] += 1
        }

        let sorted = counts.sorted { $0.value > $1.value }

        if sorted.count <= 7 {
            return sorted.map { GenreCount(genre: $0.key, count: $0.value) }
        }

        let top6 = sorted.prefix(6)
        let otherCount = sorted.dropFirst(6).reduce(0) { $0 + $1.value }

        var result = top6.map { GenreCount(genre: $0.key, count: $0.value) }
        if otherCount > 0 {
            result.append(GenreCount(genre: "Other", count: otherCount))
        }
        return result
    }

    static func classifyGenre(subjects: [String]) -> String {
        let lowered = subjects.map { $0.lowercased() }

        for (genre, keywords) in genreKeywords {
            for subject in lowered {
                for keyword in keywords {
                    if subject.contains(keyword) {
                        return genre
                    }
                }
            }
        }

        return subjects.isEmpty ? "Uncategorised" : "Other"
    }

    // MARK: - Format breakdown

    struct FormatCount: Identifiable {
        let format: String
        let count: Int
        var id: String { format }
    }

    static func formatBreakdown(_ books: [Book]) -> [FormatCount] {
        var counts = [String: Int]()
        for book in books {
            counts[book.format.rawValue, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
            .map { FormatCount(format: $0.key, count: $0.value) }
    }

    // MARK: - Reading pace

    static func averageDaysPerBook(_ books: [Book]) -> Int? {
        let durations = books.compactMap { book -> Int? in
            guard let start = book.dateStarted, let finish = book.dateFinished else { return nil }
            let days = Calendar.current.dateComponents([.day], from: start, to: finish).day ?? 0
            return max(days, 1)
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / durations.count
    }

    // MARK: - Extremes

    static func longestBook(_ books: [Book]) -> Book? {
        books.filter { $0.pageCount != nil }.max { ($0.pageCount ?? 0) < ($1.pageCount ?? 0) }
    }

    static func shortestBook(_ books: [Book]) -> Book? {
        books.filter { ($0.pageCount ?? 0) > 0 }.min { ($0.pageCount ?? 0) < ($1.pageCount ?? 0) }
    }

    static func fastestRead(_ books: [Book]) -> (book: Book, days: Int)? {
        var best: (Book, Int)?
        for book in books {
            guard let start = book.dateStarted, let finish = book.dateFinished else { continue }
            let days = max(Calendar.current.dateComponents([.day], from: start, to: finish).day ?? 0, 1)
            if best == nil || days < best!.1 {
                best = (book, days)
            }
        }
        return best.map { ($0.0, $0.1) }
    }

    // MARK: - DNF rate

    static func dnfRate(read: [Book], dnf: [Book]) -> (percentage: Double, count: Int) {
        let total = read.count + dnf.count
        guard total > 0 else { return (0, 0) }
        return (Double(dnf.count) / Double(total) * 100, dnf.count)
    }

    // MARK: - Reading streak

    static func currentStreak(from readingDays: [ReadingDay]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let dates = Set(readingDays.map { calendar.startOfDay(for: $0.date) })

        // Grace window: streak doesn't break if user hasn't read yet today
        guard dates.contains(today) || dates.contains(yesterday) else {
            return 0
        }

        var streak = 0
        var day = dates.contains(today) ? today : yesterday
        while dates.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    // MARK: - Goal pace

    static func goalPace(booksRead: Int, target: Int, year: Int) -> Int {
        let calendar = Calendar.current
        let now = Date.now
        let currentYear = calendar.component(.year, from: now)

        guard currentYear == year else {
            return booksRead - target
        }

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let totalDays = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let expectedBooks = Double(target) * Double(dayOfYear) / Double(totalDays)
        return booksRead - Int(expectedBooks.rounded())
    }

    // MARK: - Longest streak in a year

    static func longestStreak(readingDays: [ReadingDay], year: Int) -> Int {
        let calendar = Calendar.current
        let dates = Set(readingDays.compactMap { day -> Date? in
            let d = calendar.startOfDay(for: day.date)
            return calendar.component(.year, from: d) == year ? d : nil
        })

        guard !dates.isEmpty else { return 0 }

        let sorted = dates.sorted()
        var longest = 1
        var current = 1

        for i in 1..<sorted.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: sorted[i - 1])!
            if calendar.isDate(sorted[i], inSameDayAs: expected) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    // MARK: - Estimated reading hours

    static func estimatedReadingHours(books: [Book]) -> Int {
        // 1.7 minutes per page, converted to hours — excludes audiobooks
        let nonAudiobooks = books.filter { $0.format != .audiobook }
        let totalMinutes = nonAudiobooks.compactMap(\.pageCount).reduce(0.0) { $0 + Double($1) * 1.7 }
        return Int((totalMinutes / 60.0).rounded())
    }

    // MARK: - Listening hours

    static func listeningHours(_ books: [Book]) -> Double {
        let finishedAudiobooks = books.filter { $0.format == .audiobook && $0.shelf == .read }
        let totalMinutes = finishedAudiobooks.compactMap(\.durationMinutes).reduce(0, +)
        return Double(totalMinutes) / 60.0
    }

    // MARK: - Total hours (reading + listening)

    static func totalHours(_ books: [Book]) -> Double {
        Double(estimatedReadingHours(books: books)) + listeningHours(books)
    }

    // MARK: - Favourite author

    static func favouriteAuthor(books: [Book]) -> String? {
        var counts = [String: Int]()
        for book in books {
            counts[book.authorName, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Slowest read

    static func slowestRead(_ books: [Book]) -> (book: Book, days: Int)? {
        var worst: (Book, Int)?
        for book in books {
            guard let start = book.dateStarted, let finish = book.dateFinished else { continue }
            let days = max(Calendar.current.dateComponents([.day], from: start, to: finish).day ?? 0, 1)
            if worst == nil || days > worst!.1 {
                worst = (book, days)
            }
        }
        return worst.map { ($0.0, $0.1) }
    }

    // MARK: - Helpers

    private static func finishedInYear(_ book: Book, year: Int) -> Bool {
        guard let date = book.dateFinished else { return false }
        return Calendar.current.component(.year, from: date) == year
    }
}

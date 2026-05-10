import SwiftUI
import SwiftData
import Charts

struct UnwrappedView: View {
    let year: Int

    @Query private var allBooks: [Book]
    @Query private var goals: [ReadingGoal]

    @AppStorage("includePrivateBooksInStats") private var includePrivateBooksInStats: Bool = false

    @State private var currentPage = 0
    @State private var autoAdvanceActive = true
    @State private var showUnwrappedShareSheet = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Books filtered to exclude private unless the stats toggle is on.
    private var statsBooks: [Book] {
        if includePrivateBooksInStats {
            return allBooks
        }
        return allBooks.filter { !$0.isPrivate }
    }

    private var readBooks: [Book] {
        StatsCalculator.booksRead(from: statsBooks, filter: .year(year))
    }

    private var totalPages: Int {
        StatsCalculator.totalPages(readBooks)
    }

    private var estimatedHours: Int {
        StatsCalculator.estimatedReadingHours(books: readBooks)
    }

    private var topBook: Book? {
        readBooks.filter { ($0.userRating ?? 0) > 0 }
            .max { ($0.userRating ?? 0) < ($1.userRating ?? 0) }
    }

    private var topGenre: (genre: String, count: Int, percentage: String)? {
        let genres = StatsCalculator.genreBreakdown(readBooks)
        guard let top = genres.first else { return nil }
        let total = genres.reduce(0) { $0 + $1.count }
        let pct = total > 0 ? String(format: "%.0f%%", Double(top.count) / Double(total) * 100) : "0%"
        return (top.genre, top.count, pct)
    }

    private var favouriteAuthor: String? {
        StatsCalculator.favouriteAuthor(books: readBooks)
    }

    private var averageDays: Int? {
        StatsCalculator.averageDaysPerBook(readBooks)
    }

    private var fastestRead: (book: Book, days: Int)? {
        StatsCalculator.fastestRead(readBooks)
    }

    private var longestRead: (book: Book, days: Int)? {
        StatsCalculator.slowestRead(readBooks)
    }

    private var longestStreak: Int {
        StatsCalculator.longestStreak(books: statsBooks, year: year)
    }

    private var goalForYear: ReadingGoal? {
        goals.first { $0.year == year }
    }

    private let totalCards = 10

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                openerCard.tag(0)
                totalStatsCard.tag(1)
                topBookCard.tag(2)
                topGenreCard.tag(3)
                favouriteAuthorCard.tag(4)
                readingPaceCard.tag(5)
                monthlyBreakdownCard.tag(6)
                streakCard.tag(7)
                goalProgressCard.tag(8)
                closerCard.tag(9)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .accessibilityValue("Card \(currentPage + 1) of \(totalCards)")

            // Tap targets on left/right edges for tap-to-navigate
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        autoAdvanceActive = false
                        withAnimation {
                            currentPage = max(currentPage - 1, 0)
                        }
                    }
                    .frame(width: 60)

                Spacer()

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        autoAdvanceActive = false
                        withAnimation {
                            currentPage = min(currentPage + 1, totalCards - 1)
                        }
                    }
                    .frame(width: 60)
            }
            .allowsHitTesting(true)
        }
        .overlay(alignment: .topTrailing) {
            closeButton
        }
        .overlay(alignment: .bottomTrailing) {
            if currentPage < totalCards - 1 {
                shareYearButton
            }
        }
        .sheet(isPresented: $showUnwrappedShareSheet) {
            // Always exclude private books from shared content regardless of stats toggle
            let shareBooks = StatsCalculator.booksRead(from: allBooks.filter { !$0.isPrivate }, filter: .year(year))
            let shareTopBook = shareBooks.filter { ($0.userRating ?? 0) > 0 }
                .max { ($0.userRating ?? 0) < ($1.userRating ?? 0) }
            let shareGenres = StatsCalculator.genreBreakdown(shareBooks)
            let shareTopGenre: (genre: String, count: Int, percentage: String)? = shareGenres.first.map { top in
                let total = shareGenres.reduce(0) { $0 + $1.count }
                let pct = total > 0 ? String(format: "%.0f%%", Double(top.count) / Double(total) * 100) : "0%"
                return (top.genre, top.count, pct)
            }
            UnwrappedShareSheet(
                year: year,
                booksReadCount: shareBooks.count,
                totalPages: StatsCalculator.totalPages(shareBooks),
                estimatedHours: StatsCalculator.estimatedReadingHours(books: shareBooks),
                topBook: shareTopBook,
                topGenre: shareTopGenre,
                favouriteAuthor: StatsCalculator.favouriteAuthor(books: shareBooks),
                longestStreak: StatsCalculator.longestStreak(books: allBooks.filter { !$0.isPrivate }, year: year),
                goalTarget: goalForYear?.target,
                goalMet: goalForYear.map { shareBooks.count >= $0.target } ?? false,
                averageDays: StatsCalculator.averageDaysPerBook(shareBooks),
                fastestRead: StatsCalculator.fastestRead(shareBooks).map { (title: $0.book.title, days: $0.days) },
                longestRead: StatsCalculator.slowestRead(shareBooks).map { (title: $0.book.title, days: $0.days) },
                monthlyData: StatsCalculator.booksPerMonth(shareBooks)
            )
        }
        .onReceive(
            Timer.publish(every: 5, on: .main, in: .common).autoconnect()
        ) { _ in
            guard autoAdvanceActive else { return }
            withAnimation {
                if currentPage < totalCards - 1 {
                    currentPage += 1
                } else {
                    autoAdvanceActive = false
                }
            }
        }
        .onChange(of: currentPage) { _, _ in
            // Any manual swipe pauses auto-advance
            autoAdvanceActive = false
        }
        .statusBarHidden()
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next card") {
            withAnimation {
                currentPage = min(currentPage + 1, totalCards - 1)
            }
            autoAdvanceActive = false
        }
        .accessibilityAction(named: "Previous card") {
            withAnimation {
                currentPage = max(currentPage - 1, 0)
            }
            autoAdvanceActive = false
        }
        .accessibilityAction(.magicTap) {
            autoAdvanceActive.toggle()
        }
    }

    // MARK: - Navigation

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.7))
                .padding()
        }
        .accessibilityLabel("Close")
        .accessibilityAddTraits(.isButton)
    }

    private var shareYearButton: some View {
        Button {
            showUnwrappedShareSheet = true
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .padding()
        .accessibilityLabel("Share your year in review")
        .accessibilityHint("Opens share options")
    }

    // MARK: - Cards

    private var openerCard: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "books.vertical.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, options: reduceMotion ? .nonRepeating : .repeating.speed(0.3))

                Text("Your \(String(year))\nin Books")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Spacer()
            }
        }
    }

    private var totalStatsCard: some View {
        UnwrappedCard {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Text("\(readBooks.count)")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundStyle(Color.accentColor)
                    Text("books read")
                        .font(.title3)
                }

                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(totalPages.formatted())")
                            .font(.title2.bold())
                        Text("pages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 4) {
                        Text("~\(estimatedHours)")
                            .font(.title2.bold())
                        Text("hours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }

    private var topBookCard: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()

                Text("Top Rated")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

                if let book = topBook {
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)

                        Text(book.title)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text(book.authorName)
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        if let rating = book.userRating {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                                        .foregroundStyle(.yellow)
                                }
                            }
                            .font(.title3)
                        }
                    }
                } else {
                    Text("No rated books")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var topGenreCard: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()

                Text("Top Genre")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

                if let genre = topGenre {
                    VStack(spacing: 12) {
                        Image(systemName: "tag.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor)

                        Text(genre.genre)
                            .font(.largeTitle.bold())

                        Text("\(genre.count) books \u{00B7} \(genre.percentage)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No genre data")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var favouriteAuthorCard: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()

                Text("Favourite Author")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

                if let author = favouriteAuthor {
                    VStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor)

                        Text(author)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("No author data")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var readingPaceCard: some View {
        UnwrappedCard {
            VStack(spacing: 32) {
                Spacer()

                Text("Reading Pace")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

                if let avg = averageDays {
                    VStack(spacing: 8) {
                        Text("\(avg)")
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .foregroundStyle(Color.accentColor)
                        Text("days per book on average")
                            .font(.title3)
                    }
                }

                HStack(spacing: 32) {
                    if let fastest = fastestRead {
                        VStack(spacing: 4) {
                            Text("\(fastest.days)d")
                                .font(.title2.bold())
                                .foregroundStyle(.green)
                            Text("fastest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(fastest.book.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if let longest = longestRead {
                        VStack(spacing: 4) {
                            Text("\(longest.days)d")
                                .font(.title2.bold())
                                .foregroundStyle(.orange)
                            Text("longest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(longest.book.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal)
        }
    }

    private var monthlyBreakdownCard: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()

                Text("Monthly Breakdown")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

                let data = StatsCalculator.booksPerMonth(readBooks)
                Chart(data) { item in
                    BarMark(
                        x: .value("Month", item.monthName),
                        y: .value("Books", item.count)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxisLabel("Books")
                .frame(height: 200)
                .padding(.horizontal)

                Spacer()
            }
        }
    }

    private var streakCard: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()

                Text("Longest Streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)

                    Text("\(longestStreak)")
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundStyle(.orange)

                    Text("consecutive days reading")
                        .font(.title3)
                }

                Spacer()
            }
        }
    }

    private var goalProgressCard: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()

                Text("Reading Goal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

                if let goal = goalForYear {
                    let met = readBooks.count >= goal.target
                    VStack(spacing: 12) {
                        Image(systemName: met ? "trophy.fill" : "target")
                            .font(.largeTitle)
                            .foregroundStyle(met ? Color.yellow : Color.accentColor)

                        Text("\(readBooks.count) of \(goal.target)")
                            .font(.system(.largeTitle, design: .rounded).bold())

                        Text(met ? "Goal reached!" : "books towards your goal")
                            .font(.title3)
                            .foregroundStyle(met ? .green : .secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No goal set for \(String(year))")
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }

    private var closerCard: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)

                Text("See you in\n\(String(year + 1))")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Keep turning those pages.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button {
                    showUnwrappedShareSheet = true
                } label: {
                    Label("Share Your Year", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }
}

// MARK: - Unwrapped Card Container

struct UnwrappedCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color(white: 0.1), Color(white: 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

// MARK: - Past Unwrapped List

struct PastUnwrappedListView: View {
    let availableYears: [Int]

    var body: some View {
        List(availableYears, id: \.self) { year in
            NavigationLink {
                UnwrappedView(year: year)
            } label: {
                Label("Your \(String(year)) in Books", systemImage: "gift.fill")
            }
        }
        .navigationTitle("Past Unwrapped")
    }
}

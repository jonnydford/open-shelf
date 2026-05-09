import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query private var books: [Book]
    @Query private var goals: [ReadingGoal]

    @State private var filter: YearFilter = .year(Calendar.current.component(.year, from: .now))

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    private var availableYears: [Int] {
        let years = Set(
            books.compactMap { $0.dateFinished.map { Calendar.current.component(.year, from: $0) } }
        )
        var all = years
        all.insert(currentYear)
        return all.sorted(by: >)
    }

    private var readBooks: [Book] {
        StatsCalculator.booksRead(from: books, filter: filter)
    }

    private var dnfBooks: [Book] {
        StatsCalculator.dnfBooks(from: books, filter: filter)
    }

    private var goalForSelectedYear: ReadingGoal? {
        guard case .year(let year) = filter else { return nil }
        return goals.first { $0.year == year }
    }

    var body: some View {
        NavigationStack {
            Group {
                if readBooks.count < 3 && goalForSelectedYear == nil {
                    emptyState
                } else {
                    dashboard
                }
            }
            .navigationTitle("Stats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    yearMenu
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            ContentUnavailableView(
                "Not Enough Data",
                systemImage: "chart.bar",
                description: Text("Read a few more books to unlock your stats.")
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Stats you'll unlock")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tertiary)

                VStack(alignment: .leading, spacing: 8) {
                    statsPreviewRow(icon: "chart.bar.fill", label: "Books per month chart")
                    statsPreviewRow(icon: "chart.pie.fill", label: "Genre breakdown")
                    statsPreviewRow(icon: "gauge.medium", label: "Reading pace")
                    statsPreviewRow(icon: "flame.fill", label: "Reading streak")
                    statsPreviewRow(icon: "star.fill", label: "Average rating")
                    statsPreviewRow(icon: "book.closed.fill", label: "Longest & shortest reads")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .opacity(0.5)
            .padding(.horizontal)
        }
    }

    private func statsPreviewRow(icon: String, label: String) -> some View {
        Label(label, systemImage: icon)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    // MARK: - Year Menu

    private var yearMenu: some View {
        Menu {
            Button("All Time") { filter = .allTime }
            Divider()
            ForEach(availableYears, id: \.self) { year in
                Button(String(year)) { filter = .year(year) }
            }
        } label: {
            HStack(spacing: 4) {
                Text(filter.displayName)
                    .font(.subheadline.bold())
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 16) {
                goalSection
                summaryHeader
                booksPerMonthSection
                pagesPerMonthSection
                genreSection
                statsGrid
            }
            .padding()
        }
    }

    // MARK: - Goal Section

    @ViewBuilder
    private var goalSection: some View {
        if case .year(let year) = filter {
            ReadingGoalView(
                booksReadCount: readBooks.count,
                year: year,
                goal: goalForSelectedYear
            )
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        let pages = StatsCalculator.totalPages(readBooks)

        return VStack(spacing: 4) {
            Text("\(filter.displayName): \(readBooks.count) book\(readBooks.count == 1 ? "" : "s") read")
                .font(.title3.bold())

            Text("\(pages.formatted()) pages")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Charts

    private var booksPerMonthSection: some View {
        NavigationLink {
            BooksPerMonthDetailView()
        } label: {
            BooksPerMonthChart(books: readBooks, filter: filter)
        }
        .buttonStyle(.plain)
    }

    private var pagesPerMonthSection: some View {
        PagesPerMonthChart(books: readBooks, filter: filter)
    }

    private var genreSection: some View {
        NavigationLink {
            GenreBreakdownDetailView()
        } label: {
            GenreBreakdownChart(books: readBooks)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            averageRatingCard
            readingPaceCard
            longestBookCard
            shortestBookCard
            fastestReadCard
            dnfRateCard
            streakCard
        }
    }

    private var averageRatingCard: some View {
        StatCard(title: "Average Rating") {
            if let avg = StatsCalculator.averageRating(readBooks) {
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", avg))
                        .font(.title.bold())
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: Double(star) <= avg.rounded() ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            } else {
                Text("--")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var readingPaceCard: some View {
        StatCard(title: "Reading Pace") {
            if let days = StatsCalculator.averageDaysPerBook(readBooks) {
                VStack(spacing: 4) {
                    Text("\(days)")
                        .font(.title.bold())
                    Text("days per book")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("--")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var longestBookCard: some View {
        StatCard(title: "Longest Book") {
            if let book = StatsCalculator.longestBook(readBooks) {
                VStack(spacing: 4) {
                    Text("\(book.pageCount ?? 0)")
                        .font(.title.bold())
                    Text(book.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("--")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var shortestBookCard: some View {
        StatCard(title: "Shortest Book") {
            if let book = StatsCalculator.shortestBook(readBooks) {
                VStack(spacing: 4) {
                    Text("\(book.pageCount ?? 0)")
                        .font(.title.bold())
                    Text(book.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("--")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fastestReadCard: some View {
        StatCard(title: "Fastest Read") {
            if let result = StatsCalculator.fastestRead(readBooks) {
                VStack(spacing: 4) {
                    Text("\(result.days) day\(result.days == 1 ? "" : "s")")
                        .font(.title3.bold())
                    Text(result.book.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            } else {
                Text("--")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dnfRateCard: some View {
        StatCard(title: "DNF Rate") {
            let rate = StatsCalculator.dnfRate(read: readBooks, dnf: dnfBooks)
            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", rate.percentage))
                    .font(.title.bold())
                Text("\(rate.count) book\(rate.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var streakCard: some View {
        StatCard(title: "Reading Streak") {
            let streak = StatsCalculator.currentStreak(from: books)
            VStack(spacing: 4) {
                Text("\(streak)")
                    .font(.title.bold())
                Text("day\(streak == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard<Content: View>: View {
    let title: String
    var accessibilityValueText: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .if(accessibilityValueText != nil) { view in
            view.accessibilityLabel(title)
                .accessibilityValue(accessibilityValueText!)
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Pages Per Month Chart

struct PagesPerMonthChart: View {
    let books: [Book]
    let filter: YearFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pages Per Month")
                .font(.headline)

            chartContent
                .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pages Per Month chart")
        .accessibilityValue(pagesChartAccessibilityValue)
    }

    private var pagesChartAccessibilityValue: String {
        switch filter {
        case .year:
            let data = StatsCalculator.pagesPerMonth(books)
            let nonZero = data.filter { $0.pages > 0 }
            if nonZero.isEmpty { return "No pages read" }
            let parts = nonZero.map { "\($0.monthName): \($0.pages) pages" }
            return parts.joined(separator: ", ")
        case .allTime:
            let total = books.compactMap(\.pageCount).reduce(0, +)
            return "\(total) pages read across all years"
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        switch filter {
        case .year:
            let data = StatsCalculator.pagesPerMonth(books)
            Chart(data) { item in
                BarMark(
                    x: .value("Month", item.monthName),
                    y: .value("Pages", item.pages)
                )
                .foregroundStyle(Color.indigo.gradient)
                .cornerRadius(4)
            }
            .chartYAxisLabel("Pages")
            .animation(.easeInOut, value: data.map(\.pages))

        case .allTime:
            let data = pagesByYear()
            Chart(data) { item in
                BarMark(
                    x: .value("Year", item.label),
                    y: .value("Pages", item.pages)
                )
                .foregroundStyle(Color.indigo.gradient)
                .cornerRadius(4)
            }
            .chartYAxisLabel("Pages")
        }
    }

    private func pagesByYear() -> [YearPages] {
        var pages = [Int: Int]()
        for book in books {
            if let date = book.dateFinished, let pc = book.pageCount {
                let year = Calendar.current.component(.year, from: date)
                pages[year, default: 0] += pc
            }
        }
        return pages.keys.sorted().map { YearPages(label: String($0), pages: pages[$0, default: 0]) }
    }
}

private struct YearPages: Identifiable {
    let label: String
    let pages: Int
    var id: String { label }
}

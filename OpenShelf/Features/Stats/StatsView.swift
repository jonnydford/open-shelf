import SwiftUI
import SwiftData
import Charts
import WidgetKit

struct StatsView: View {
    @Query private var books: [Book]
    @Query private var goals: [ReadingGoal]
    @Query private var readingDays: [ReadingDay]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("includePrivateBooksInStats") private var includePrivateBooksInStats: Bool = false

    @State private var filter: YearFilter = .year(Calendar.current.component(.year, from: .now))
    @State private var didMarkReadToday = false
    @Environment(BookRepository.self) private var repository

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    /// Books filtered to exclude private unless the stats toggle is on.
    private var statsBooks: [Book] {
        if includePrivateBooksInStats {
            return books
        }
        return books.filter { !$0.isPrivate }
    }

    /// ReadingDays filtered to exclude activity from private books.
    private var statsReadingDays: [ReadingDay] {
        if includePrivateBooksInStats { return readingDays }
        let privateKeys = Set(books.filter(\.isPrivate).map(\.olWorkKey))
        return readingDays.filter { day in
            guard let key = day.bookKey else { return true }
            return !privateKeys.contains(key)
        }
    }

    private var availableYears: [Int] {
        let years = Set(
            statsBooks.compactMap { $0.dateFinished.map { Calendar.current.component(.year, from: $0) } }
        )
        var all = years
        all.insert(currentYear)
        return all.sorted(by: >)
    }

    private var readBooks: [Book] {
        StatsCalculator.booksRead(from: statsBooks, filter: filter)
    }

    private var dnfBooks: [Book] {
        StatsCalculator.dnfBooks(from: statsBooks, filter: filter)
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

    private var booksNeeded: Int {
        max(0, 3 - readBooks.count)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            ContentUnavailableView(
                "You're getting started!",
                systemImage: "chart.bar",
                description: Text("Read \(booksNeeded) more book\(booksNeeded == 1 ? "" : "s") to unlock your full stats.")
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            .opacity(0.5)
            .padding(.horizontal)
        }
    }

    private func statsPreviewRow(icon: String, label: String) -> some View {
        Label {
            Text(label)
        } icon: {
            Image(systemName: icon)
                .frame(width: 20, alignment: .center)
        }
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
        .accessibilityLabel("Filter by year")
        .accessibilityHint("Double tap to change year filter")
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 16) {
                goalSection
                unwrappedBanner
                summaryHeader
                streakHeader
                badgesSection
                booksPerMonthSection
                pagesPerMonthSection
                genreSection
                formatSection
                statsGrid
            }
            .padding()
        }
    }

    // MARK: - Badges

    private var badges: [Badge] {
        let streak = StatsCalculator.currentStreak(from: statsReadingDays)
        let goalMet: Bool = {
            guard let goal = goalForSelectedYear else { return false }
            return readBooks.count >= goal.target
        }()
        return BadgeEngine.evaluateBadges(books: statsBooks, streak: streak, goalMet: goalMet)
    }

    private var unlockedBadgeCount: Int {
        badges.filter(\.isUnlocked).count
    }

    // MARK: - Unwrapped years

    private var unwrappedYears: [Int] {
        let yearCounts = Dictionary(
            grouping: statsBooks.filter { $0.shelf == .read && $0.dateFinished != nil },
            by: { Calendar.current.component(.year, from: $0.dateFinished!) }
        )
        return yearCounts.filter { $0.value.count >= 5 }.keys.sorted(by: >)
    }

    @State private var showUnwrapped = false

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
        let readingHrs = StatsCalculator.estimatedReadingHours(books: readBooks)
        let listeningHrs = StatsCalculator.listeningHours(readBooks)
        let hasReadingHours = readingHrs > 0
        let hasListeningHours = listeningHrs >= 0.5

        return VStack(spacing: 4) {
            Text("\(filter.displayName): \(readBooks.count) book\(readBooks.count == 1 ? "" : "s") read")
                .font(.title3.bold())

            Text("\(pages.formatted()) pages")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if hasReadingHours && hasListeningHours {
                Text("\(readingHrs) hours read \u{00B7} \(Int(listeningHrs.rounded())) hours listened")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if hasReadingHours {
                Text("\(readingHrs) hours read")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if hasListeningHours {
                Text("\(Int(listeningHrs.rounded())) hours listened")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Unwrapped Banner

    private func booksReadInYear(_ year: Int) -> Int {
        StatsCalculator.booksRead(from: statsBooks, filter: .year(year)).count
    }

    @ViewBuilder
    private var unwrappedBanner: some View {
        if case .year(let year) = filter, unwrappedYears.contains(year) {
            Button {
                showUnwrapped = true
            } label: {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your \(String(year)) Unwrapped")
                            .font(.subheadline.bold())
                        Text("See your year in review")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $showUnwrapped) {
                UnwrappedView(year: year)
            }
        } else if case .year(let year) = filter, !unwrappedYears.contains(year), booksReadInYear(year) > 0 {
            // User has some books but fewer than 5 -- show teaser at reduced opacity
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Books Unwrapped")
                        .font(.subheadline.bold())
                    Text("Read more to unlock your Books Unwrapped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            .opacity(0.5)
        } else if unwrappedYears.count > 1 {
            NavigationLink {
                PastUnwrappedListView(availableYears: unwrappedYears)
            } label: {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Past Unwrapped")
                            .font(.subheadline.bold())
                        Text("Review previous years")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Streak Section

    private var readToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return statsReadingDays.contains { calendar.isDate($0.date, inSameDayAs: today) }
    }

    private var streakHeader: some View {
        let streak = StatsCalculator.currentStreak(from: statsReadingDays)
        let best = StatsCalculator.bestStreak(from: statsReadingDays)

        return VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .font(streak >= 30 ? .title : (streak >= 7 ? .title2 : .title3))
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: streak)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak) day streak")
                        .font(.headline)
                    if best > streak {
                        Text("Best: \(best) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if streak > 0 {
                        Text("Personal best!")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Start reading to build a streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if readToday || didMarkReadToday {
                    Label("Read today", systemImage: "checkmark.circle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                } else {
                    Button {
                        markReadToday()
                    } label: {
                        Text("I read today")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.orange.opacity(0.2), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            streakHeatmap
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading streak: \(streak) days. Best: \(best) days.")
    }

    private static let heatmapDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    @State private var toggledDates: Set<Date> = []

    private static let backfillLimit = 14

    private func isEditable(_ day: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard day <= today else { return false }
        let daysAgo = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        return daysAgo < Self.backfillLimit
    }

    private var streakHeatmap: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dates = Set(statsReadingDays.map { calendar.startOfDay(for: $0.date) })
        let dayLabels = calendar.veryShortWeekdaySymbols

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    let daysAgo = 6 - dayIndex
                    let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
                    let weekday = calendar.component(.weekday, from: day)
                    Text(dayLabels[weekday - 1])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                }
                Spacer()
            }

            ForEach(0..<2, id: \.self) { week in
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let daysAgo = (1 - week) * 7 + (6 - dayIndex)
                        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
                        let didRead = dates.contains(day)
                        let editable = isEditable(day)

                        ZStack {
                            Circle()
                                .fill(didRead ? Color.orange : (editable ? Color.primary.opacity(0.15) : Color.primary.opacity(0.08)))
                                .frame(width: 14, height: 14)

                            if editable && !didRead {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                    .frame(width: 14, height: 14)
                            }
                        }
                        .scaleEffect(toggledDates.contains(day) ? 1.3 : 1.0)
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                        .onTapGesture {
                            guard editable else { return }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.spring(duration: 0.3, bounce: 0.5)) {
                                _ = repository.toggleReadingDay(for: day)
                                toggledDates.insert(day)
                            }
                            Task {
                                try? await Task.sleep(for: .milliseconds(400))
                                await MainActor.run {
                                    withAnimation { toggledDates.remove(day) }
                                }
                            }
                        }
                        .opacity(editable ? 1.0 : 0.6)
                        .accessibilityLabel("\(Self.heatmapDateFormatter.string(from: day)): \(didRead ? "read" : "did not read")")
                        .accessibilityAddTraits(editable ? .isButton : [])
                        .accessibilityHint(editable ? "Tap to toggle" : "")
                    }
                    Spacer()
                }
            }

            Text("Tap a day to mark it as read")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)

            NavigationLink {
                ReadingCalendarView()
            } label: {
                Text("See all")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 4)
        }
    }

    private func markReadToday() {
        withAnimation {
            ReadingDay.record(in: modelContext)
            try? modelContext.save()
            didMarkReadToday = true
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Badges Section

    private var badgesSection: some View {
        NavigationLink {
            BadgesView(badges: badges)
        } label: {
            HStack {
                Image(systemName: "medal.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Badges")
                        .font(.subheadline.bold())
                    Text("\(unlockedBadgeCount) of \(BadgeEngine.totalBadgeCount) badges earned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
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

    @ViewBuilder
    private var formatSection: some View {
        let breakdown = StatsCalculator.formatBreakdown(readBooks)
        let hasMixedFormats = breakdown.count > 1
        if hasMixedFormats {
            VStack(alignment: .leading, spacing: 12) {
                Text("Format Breakdown")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                ForEach(breakdown, id: \.format) { item in
                    HStack {
                        Text(item.format)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
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
        let streak = StatsCalculator.currentStreak(from: statsReadingDays)
        let flameIcon: String = streak >= 30 ? "flame.fill" : "flame"
        let flameSize: Font = streak >= 30 ? .title : (streak >= 7 ? .title2 : .title3)

        return StatCard(title: "Reading Streak") {
            VStack(spacing: 4) {
                Image(systemName: flameIcon)
                    .font(flameSize)
                    .foregroundStyle(.orange)
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
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
                .accessibilityAddTraits(.isHeader)

            chartContent
                .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
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
                .cornerRadius(CornerRadius.xSmall)
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
                .cornerRadius(CornerRadius.xSmall)
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

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents
import UIKit

// MARK: - Timeline Entry

struct CurrentlyReadingEntry: TimelineEntry {
    let date: Date
    let title: String?
    let authorName: String?
    let currentPage: Int?
    let pageCount: Int?
    let dateStarted: Date?
    let coverImageID: Int?
    let olWorkKey: String?
    let isAudiobook: Bool
    let currentChapter: Int?
    let chapterCount: Int?

    var progress: Double {
        if isAudiobook {
            guard let currentChapter, let chapterCount, chapterCount > 0 else { return 0 }
            return min(Double(currentChapter) / Double(chapterCount), 1.0)
        }
        guard let currentPage, let pageCount, pageCount > 0 else { return 0 }
        return min(Double(currentPage) / Double(pageCount), 1.0)
    }

    var percentage: Int {
        Int(progress * 100)
    }

    var daysReading: Int? {
        guard let dateStarted else { return nil }
        let days = Calendar.current.dateComponents([.day], from: dateStarted, to: .now).day ?? 0
        return max(days, 0)
    }

    static var placeholder: CurrentlyReadingEntry {
        CurrentlyReadingEntry(
            date: .now,
            title: "The Great Gatsby",
            authorName: "F. Scott Fitzgerald",
            currentPage: 120,
            pageCount: 218,
            dateStarted: Calendar.current.date(byAdding: .day, value: -5, to: .now),
            coverImageID: nil,
            olWorkKey: nil,
            isAudiobook: false,
            currentChapter: nil,
            chapterCount: nil
        )
    }

    static var empty: CurrentlyReadingEntry {
        CurrentlyReadingEntry(
            date: .now,
            title: nil,
            authorName: nil,
            currentPage: nil,
            pageCount: nil,
            dateStarted: nil,
            coverImageID: nil,
            olWorkKey: nil,
            isAudiobook: false,
            currentChapter: nil,
            chapterCount: nil
        )
    }
}

// MARK: - Additional Entries for Large Widget

struct LargeWidgetData {
    let books: [CurrentlyReadingEntry]
    let booksReadThisYear: Int
    let goalProgress: (read: Int, target: Int)?
    let streak: Int
}

// MARK: - Timeline Provider

struct CurrentlyReadingProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CurrentlyReadingEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectBookIntent, in context: Context) async -> CurrentlyReadingEntry {
        context.isPreview ? .placeholder : fetchEntry(for: configuration)
    }

    func timeline(for configuration: SelectBookIntent, in context: Context) async -> Timeline<CurrentlyReadingEntry> {
        let entry = fetchEntry(for: configuration)
        return Timeline(entries: [entry], policy: .atEnd)
    }

    private func fetchEntry(for configuration: SelectBookIntent) -> CurrentlyReadingEntry {
        do {
            let context = try WidgetSharedStore.makeContext()
            let descriptor = FetchDescriptor<Book>()
            let allBooks = try context.fetch(descriptor)

            let readingBooks = allBooks
                .filter { $0.shelf == .reading && !$0.isPrivate }
                .sorted { ($0.dateStarted ?? .distantPast) > ($1.dateStarted ?? .distantPast) }

            let book: Book?
            if let selectedKey = configuration.book?.id {
                book = readingBooks.first { $0.olWorkKey == selectedKey } ?? readingBooks.first
            } else {
                book = readingBooks.first
            }

            guard let book else { return .empty }

            return CurrentlyReadingEntry(
                date: .now,
                title: book.title,
                authorName: book.authorName,
                currentPage: book.currentPage,
                pageCount: book.pageCount,
                dateStarted: book.dateStarted,
                coverImageID: book.coverImageID,
                olWorkKey: book.olWorkKey,
                isAudiobook: book.format == .audiobook,
                currentChapter: book.currentChapter,
                chapterCount: book.chapterCount
            )
        } catch {
            return .empty
        }
    }
}

// MARK: - Large Widget Provider

struct LargeWidgetProvider: TimelineProvider {
    struct LargeEntry: TimelineEntry {
        let date: Date
        let data: LargeWidgetData
    }

    func placeholder(in context: Context) -> LargeEntry {
        LargeEntry(date: .now, data: LargeWidgetData(
            books: [.placeholder],
            booksReadThisYear: 23,
            goalProgress: (read: 23, target: 40),
            streak: 12
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (LargeEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : fetchLargeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LargeEntry>) -> Void) {
        let entry = fetchLargeEntry()
        completion(Timeline(entries: [entry], policy: .atEnd))
    }

    private func fetchLargeEntry() -> LargeEntry {
        do {
            let context = try WidgetSharedStore.makeContext()
            let descriptor = FetchDescriptor<Book>()
            let allBooks = try context.fetch(descriptor)
            let currentYear = Calendar.current.component(.year, from: .now)

            let readingBooks = allBooks
                .filter { $0.shelf == .reading && !$0.isPrivate }
                .sorted { ($0.dateStarted ?? .distantPast) > ($1.dateStarted ?? .distantPast) }
                .prefix(3)
                .map { book in
                    CurrentlyReadingEntry(
                        date: .now,
                        title: book.title,
                        authorName: book.authorName,
                        currentPage: book.currentPage,
                        pageCount: book.pageCount,
                        dateStarted: book.dateStarted,
                        coverImageID: book.coverImageID,
                        olWorkKey: book.olWorkKey,
                        isAudiobook: book.format == .audiobook,
                        currentChapter: book.currentChapter,
                        chapterCount: book.chapterCount
                    )
                }

            let booksReadThisYear = allBooks.filter { book in
                book.shelf == .read && !book.isPrivate &&
                book.dateFinished.map { Calendar.current.component(.year, from: $0) == currentYear } ?? false
            }.count

            let goalDescriptor = FetchDescriptor<ReadingGoal>(
                predicate: #Predicate { $0.year == currentYear }
            )
            let goal = (try? context.fetch(goalDescriptor))?.first
            let goalProgress = goal.map { (read: booksReadThisYear, target: $0.target) }

            let privateKeys = Set(allBooks.filter(\.isPrivate).map(\.olWorkKey))
            let dayDescriptor = FetchDescriptor<ReadingDay>()
            let allDays = (try? context.fetch(dayDescriptor))?.filter { day in
                guard let key = day.bookKey else { return true }
                return !privateKeys.contains(key)
            } ?? []
            let streak = Self.calculateStreak(from: allDays)

            let data = LargeWidgetData(
                books: Array(readingBooks),
                booksReadThisYear: booksReadThisYear,
                goalProgress: goalProgress,
                streak: streak
            )

            return LargeEntry(date: .now, data: data)
        } catch {
            return LargeEntry(date: .now, data: LargeWidgetData(
                books: [], booksReadThisYear: 0, goalProgress: nil, streak: 0
            ))
        }
    }
    private static func calculateStreak(from readingDays: [ReadingDay]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dates = Set(readingDays.map { calendar.startOfDay(for: $0.date) })
        guard dates.contains(today) || dates.contains(yesterday) else { return 0 }
        var streak = 0
        var day = dates.contains(today) ? today : yesterday
        while dates.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }
}

// MARK: - Widget Definitions

struct CurrentlyReadingWidget: Widget {
    let kind = "CurrentlyReadingWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectBookIntent.self, provider: CurrentlyReadingProvider()) { entry in
            CurrentlyReadingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Currently Reading")
        .description("See the book you are currently reading and your progress.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

struct CurrentlyReadingLargeWidget: Widget {
    let kind = "CurrentlyReadingLargeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LargeWidgetProvider()) { entry in
            LargeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "openshelf://stats"))
        }
        .configurationDisplayName("Reading Dashboard")
        .description("See all your currently reading books and year-to-date stats.")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - Widget Views

struct CurrentlyReadingWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CurrentlyReadingEntry

    private func loadCoverImage() -> UIImage? {
        guard let coverID = entry.coverImageID else { return nil }
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.forddevinc.OpenShelf.shared"
        ) else { return nil }
        let path = groupURL.appendingPathComponent("Covers/\(coverID)_M.jpg")
        return UIImage(contentsOfFile: path.path)
    }

    private var bookDeepLink: URL? {
        guard let key = entry.olWorkKey else { return nil }
        let path = key.replacingOccurrences(of: "/works/", with: "")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "openshelf://book/\(encoded)")
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .accessoryCircular:
                circularLockScreenView
            case .accessoryRectangular:
                rectangularLockScreenView
            default:
                smallView
            }
        }
        .widgetURL(bookDeepLink)
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = entry.title {
                Image(systemName: entry.isAudiobook ? "headphones" : "book.fill")
                    .font(.title3)
                    .foregroundStyle(entry.isAudiobook ? Color.purple : Color.accentColor)

                Text(title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer(minLength: 0)

                if entry.isAudiobook {
                    if entry.chapterCount != nil {
                        ProgressView(value: entry.progress)
                            .tint(.purple)
                        Text("\(entry.percentage)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if entry.pageCount != nil {
                    ProgressView(value: entry.progress)
                        .tint(.green)
                    Text("\(entry.percentage)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                emptySmallView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(smallViewAccessibilityLabel)
    }

    private var smallViewAccessibilityLabel: String {
        guard let title = entry.title else {
            return "No books currently being read"
        }
        var label = "Currently reading \(title)"
        if let author = entry.authorName {
            label += " by \(author)"
        }
        if entry.pageCount != nil {
            label += ", \(entry.percentage) percent complete"
        }
        return label
    }

    private var emptySmallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "book.closed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Pick up a book")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("No books currently being read. Open Open Shelf to start reading.")
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        HStack(spacing: 12) {
            if let uiImage = loadCoverImage() {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 70, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                    Image(systemName: "book.closed.fill")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70, height: 100)
            }

            if let title = entry.title {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)

                    if let author = entry.authorName {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if entry.isAudiobook {
                        if let currentChapter = entry.currentChapter, let chapterCount = entry.chapterCount, chapterCount > 0 {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "headphones")
                                            .font(.caption)
                                            .foregroundStyle(.purple)
                                        Text("Chapter \(currentChapter) of \(chapterCount)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    ProgressView(value: entry.progress)
                                        .tint(.purple)
                                }

                                if let workKey = entry.olWorkKey {
                                    Button(intent: makeFinishIntent(bookID: workKey)) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.green)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Mark as finished")
                                }
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "headphones")
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                                Text("Listening")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if let currentPage = entry.currentPage, let pageCount = entry.pageCount, pageCount > 0 {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Page \(currentPage) of \(pageCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ProgressView(value: entry.progress)
                                    .tint(.green)
                            }

                            if let workKey = entry.olWorkKey {
                                HStack(spacing: 4) {
                                    Button(intent: makeUpdateIntent(bookID: workKey)) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.tint)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Add 10 pages")

                                    Button(intent: makeFinishIntent(bookID: workKey)) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.green)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Mark as finished")
                                }
                            }
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("Pick up a book")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Nothing currently being read")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mediumViewAccessibilityLabel)
    }

    private var mediumViewAccessibilityLabel: String {
        guard let title = entry.title else {
            return "No books currently being read. Open Open Shelf to start reading."
        }
        var label = "Currently reading \(title)"
        if let author = entry.authorName {
            label += " by \(author)"
        }
        if let currentPage = entry.currentPage, let pageCount = entry.pageCount, pageCount > 0 {
            label += ", page \(currentPage) of \(pageCount), \(entry.percentage) percent complete"
        }
        return label
    }

    // MARK: - Lock Screen Circular

    @ViewBuilder
    private var circularLockScreenView: some View {
        if entry.title != nil {
            Gauge(value: entry.progress) {
                Image(systemName: entry.isAudiobook ? "headphones" : "book.fill")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel(entry.isAudiobook
                ? "Listening progress, \(entry.percentage) percent"
                : "Reading progress, \(entry.percentage) percent")
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "book.closed")
                    .font(.title3)
            }
            .accessibilityLabel("No books currently being read")
        }
    }

    // MARK: - Lock Screen Rectangular

    private var rectangularLockScreenView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title = entry.title {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .widgetAccentable()

                if entry.pageCount != nil {
                    ProgressView(value: entry.progress)
                    Text("\(entry.percentage)% complete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Pick up a book", systemImage: "book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Intent Helpers

    private func makeUpdateIntent(bookID: String) -> UpdatePagesIntent {
        var intent = UpdatePagesIntent()
        intent.bookID = bookID
        intent.pagesToAdd = 10
        return intent
    }

    private func makeFinishIntent(bookID: String) -> MarkFinishedIntent {
        var intent = MarkFinishedIntent()
        intent.bookID = bookID
        return intent
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let entry: LargeWidgetProvider.LargeEntry

    private func bookDeepLink(for book: CurrentlyReadingEntry) -> URL? {
        guard let key = book.olWorkKey else { return nil }
        let path = key.replacingOccurrences(of: "/works/", with: "")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "openshelf://book/\(encoded)")
    }

    private func loadCoverImage(coverID: Int?) -> UIImage? {
        guard let coverID else { return nil }
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.forddevinc.OpenShelf.shared"
        ) else { return nil }
        let path = groupURL.appendingPathComponent("Covers/\(coverID)_M.jpg")
        return UIImage(contentsOfFile: path.path)
    }

    var body: some View {
        if entry.data.books.isEmpty {
            emptyView
        } else {
            contentView
        }
    }

    private var contentView: some View {
        VStack(spacing: 12) {
            // Stats row
            HStack(spacing: 16) {
                statPill(
                    icon: "checkmark.circle.fill",
                    value: "\(entry.data.booksReadThisYear)",
                    label: "read this year",
                    color: .green
                )

                if let goal = entry.data.goalProgress, goal.target > 0 {
                    statPill(
                        icon: "target",
                        value: "\(goal.read)/\(goal.target)",
                        label: "goal",
                        color: goal.read >= goal.target ? .green : .blue
                    )
                }

                if entry.data.streak > 0 {
                    statPill(
                        icon: "flame.fill",
                        value: "\(entry.data.streak)",
                        label: "day streak",
                        color: .orange
                    )
                }

                Spacer()
            }

            Divider()

            // Book list
            ForEach(Array(entry.data.books.enumerated()), id: \.offset) { index, book in
                if let url = bookDeepLink(for: book) {
                    Link(destination: url) {
                        bookRow(book)
                    }
                } else {
                    bookRow(book)
                }
                if index < entry.data.books.count - 1 {
                    Divider()
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func bookRow(_ book: CurrentlyReadingEntry) -> some View {
        HStack(spacing: 10) {
            if let uiImage = loadCoverImage(coverID: book.coverImageID) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.quaternary)
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(.secondary)
                }
                .frame(width: 44, height: 64)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title ?? "Unknown")
                    .font(.subheadline.bold())
                    .lineLimit(1)

                if let author = book.authorName {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if book.isAudiobook {
                    if book.chapterCount != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "headphones")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                            ProgressView(value: book.progress)
                                .tint(.purple)
                        }
                        Text("\(book.percentage)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "headphones")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                            Text("Listening")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if book.pageCount != nil {
                    ProgressView(value: book.progress)
                        .tint(.green)
                    Text("\(book.percentage)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if let workKey = book.olWorkKey {
                VStack(spacing: 4) {
                    Button(intent: makeUpdateIntent(bookID: workKey)) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add 10 pages to \(book.title ?? "book")")

                    Button(intent: makeFinishIntent(bookID: workKey)) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mark \(book.title ?? "book") as finished")
                }
            }
        }
    }

    private func statPill(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.caption.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No books in progress")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Open Open Shelf to start reading")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func makeUpdateIntent(bookID: String) -> UpdatePagesIntent {
        var intent = UpdatePagesIntent()
        intent.bookID = bookID
        intent.pagesToAdd = 10
        return intent
    }

    private func makeFinishIntent(bookID: String) -> MarkFinishedIntent {
        var intent = MarkFinishedIntent()
        intent.bookID = bookID
        return intent
    }
}

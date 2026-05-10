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

    var progress: Double {
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
            olWorkKey: nil
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
            olWorkKey: nil
        )
    }
}

// MARK: - Additional Entries for Large Widget

struct LargeWidgetData {
    let books: [CurrentlyReadingEntry]
    let booksReadThisYear: Int
    let currentStreak: Int
    let goalProgress: (read: Int, target: Int)?
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
                olWorkKey: book.olWorkKey
            )
        } catch {
            return .empty
        }
    }
}

// MARK: - Large Widget Provider

struct LargeWidgetProvider: AppIntentTimelineProvider {
    struct LargeEntry: TimelineEntry {
        let date: Date
        let data: LargeWidgetData
    }

    func placeholder(in context: Context) -> LargeEntry {
        LargeEntry(date: .now, data: LargeWidgetData(
            books: [.placeholder],
            booksReadThisYear: 23,
            currentStreak: 7,
            goalProgress: (read: 23, target: 40)
        ))
    }

    func snapshot(for configuration: SelectBookIntent, in context: Context) async -> LargeEntry {
        context.isPreview ? placeholder(in: context) : fetchLargeEntry()
    }

    func timeline(for configuration: SelectBookIntent, in context: Context) async -> Timeline<LargeEntry> {
        let entry = fetchLargeEntry()
        return Timeline(entries: [entry], policy: .atEnd)
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
                        olWorkKey: book.olWorkKey
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

            let data = LargeWidgetData(
                books: Array(readingBooks),
                booksReadThisYear: booksReadThisYear,
                currentStreak: 0,
                goalProgress: goalProgress
            )

            return LargeEntry(date: .now, data: data)
        } catch {
            return LargeEntry(date: .now, data: LargeWidgetData(
                books: [], booksReadThisYear: 0, currentStreak: 0, goalProgress: nil
            ))
        }
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
        AppIntentConfiguration(kind: kind, intent: SelectBookIntent.self, provider: LargeWidgetProvider()) { entry in
            LargeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
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
            forSecurityApplicationGroupIdentifier: "group.com.openshelf.shared"
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
                Image(systemName: "book.fill")
                    .font(.title3)
                    .foregroundStyle(.tint)

                Text(title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer(minLength: 0)

                if entry.pageCount != nil {
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

            if let title = entry.title, let workKey = entry.olWorkKey {
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

                    if let currentPage = entry.currentPage, let pageCount = entry.pageCount, pageCount > 0 {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Page \(currentPage) of \(pageCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ProgressView(value: entry.progress)
                                    .tint(.green)
                            }

                            // Interactive buttons
                            HStack(spacing: 4) {
                                Button(intent: makeUpdateIntent(bookID: workKey)) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.tint)
                                }
                                .buttonStyle(.plain)

                                Button(intent: makeFinishIntent(bookID: workKey)) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
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
    }

    // MARK: - Lock Screen Circular

    @ViewBuilder
    private var circularLockScreenView: some View {
        if entry.title != nil {
            Gauge(value: entry.progress) {
                Image(systemName: "book.fill")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "book.closed")
                    .font(.title3)
            }
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

    private func loadCoverImage(coverID: Int?) -> UIImage? {
        guard let coverID else { return nil }
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.openshelf.shared"
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

                Spacer()
            }

            Divider()

            // Book list
            ForEach(entry.data.books, id: \.olWorkKey) { book in
                bookRow(book)
                if book.olWorkKey != entry.data.books.last?.olWorkKey {
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

                if book.pageCount != nil {
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

                    Button(intent: makeFinishIntent(bookID: workKey)) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
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

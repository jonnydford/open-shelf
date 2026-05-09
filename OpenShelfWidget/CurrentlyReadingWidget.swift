import WidgetKit
import SwiftUI
import SwiftData
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
            coverImageID: nil
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
            coverImageID: nil
        )
    }
}

// MARK: - Timeline Provider

struct CurrentlyReadingProvider: TimelineProvider {
    func placeholder(in context: Context) -> CurrentlyReadingEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CurrentlyReadingEntry) -> Void) {
        completion(context.isPreview ? .placeholder : fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrentlyReadingEntry>) -> Void) {
        let entry = fetchEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func fetchEntry() -> CurrentlyReadingEntry {
        do {
            let schema = Schema([Book.self, ReadEntry.self, UserTag.self, ReadingGoal.self])
            let storeURL = WidgetSharedStore.storeURL
            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<Book>()
            let allBooks = try context.fetch(descriptor)

            // Filter to currently reading books, sorted by most recently started
            let readingBooks = allBooks
                .filter { $0.shelf == .reading }
                .sorted { ($0.dateStarted ?? .distantPast) > ($1.dateStarted ?? .distantPast) }

            guard let book = readingBooks.first else {
                return .empty
            }

            return CurrentlyReadingEntry(
                date: .now,
                title: book.title,
                authorName: book.authorName,
                currentPage: book.currentPage,
                pageCount: book.pageCount,
                dateStarted: book.dateStarted,
                coverImageID: book.coverImageID
            )
        } catch {
            return .empty
        }
    }
}

// MARK: - Widget Definition

struct CurrentlyReadingWidget: Widget {
    let kind = "CurrentlyReadingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentlyReadingProvider()) { entry in
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

// MARK: - Widget Views

struct CurrentlyReadingWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CurrentlyReadingEntry

    /// Loads a cover image from the shared App Group cache directory.
    private func loadCoverImage() -> UIImage? {
        guard let coverID = entry.coverImageID else { return nil }
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.openshelf.shared"
        ) else { return nil }
        let path = groupURL.appendingPathComponent("Covers/\(coverID)_M.jpg")
        return UIImage(contentsOfFile: path.path)
    }

    var body: some View {
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

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = entry.title {
                Image(systemName: "book.fill")
                    .font(.title3)
                    .foregroundStyle(.accent)

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
            // Cover image from shared cache, or SF Symbol placeholder
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

                    if let currentPage = entry.currentPage, let pageCount = entry.pageCount, pageCount > 0 {
                        Text("Page \(currentPage) of \(pageCount) (\(entry.percentage)%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ProgressView(value: entry.progress)
                            .tint(.green)
                    }

                    if let days = entry.daysReading, days > 0 {
                        Text("Started \(days) day\(days == 1 ? "" : "s") ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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
}

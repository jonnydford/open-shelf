import WidgetKit
import SwiftUI
import SwiftData
import AppIntents
import UIKit

// MARK: - Timeline Entry

struct ReadingStreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let readToday: Bool
    let last7Days: [Bool]
    let currentlyReading: [ReadingBookInfo]

    struct ReadingBookInfo: Identifiable {
        let id: String
        let title: String
        let authorName: String
        let coverImageID: Int?
    }

    static var placeholder: ReadingStreakEntry {
        ReadingStreakEntry(
            date: .now,
            streak: 12,
            readToday: true,
            last7Days: [true, true, false, true, true, true, true],
            currentlyReading: [
                ReadingBookInfo(id: "placeholder-1", title: "The Great Gatsby", authorName: "F. Scott Fitzgerald", coverImageID: nil),
                ReadingBookInfo(id: "placeholder-2", title: "Dune", authorName: "Frank Herbert", coverImageID: nil)
            ]
        )
    }

    static var empty: ReadingStreakEntry {
        ReadingStreakEntry(
            date: .now,
            streak: 0,
            readToday: false,
            last7Days: Array(repeating: false, count: 7),
            currentlyReading: []
        )
    }
}

// MARK: - Timeline Provider

struct ReadingStreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingStreakEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingStreakEntry) -> Void) {
        completion(context.isPreview ? .placeholder : fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingStreakEntry>) -> Void) {
        let entry = fetchEntry()
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }

    private func fetchEntry() -> ReadingStreakEntry {
        do {
            let context = try WidgetSharedStore.makeContext()
            let calendar = Calendar.current

            let bookDescriptor = FetchDescriptor<Book>()
            let allBooks = try context.fetch(bookDescriptor)

            let privateKeys = Set(allBooks.filter(\.isPrivate).map(\.olWorkKey))
            let dayDescriptor = FetchDescriptor<ReadingDay>()
            let allDays = try context.fetch(dayDescriptor).filter { day in
                guard let key = day.bookKey else { return true }
                return !privateKeys.contains(key)
            }

            let today = calendar.startOfDay(for: .now)
            let readToday = allDays.contains { calendar.isDate($0.date, inSameDayAs: today) }

            let streak = ReadingDay.streak(from: allDays.map(\.date))

            let last7Days: [Bool] = (0..<7).reversed().map { offset in
                let day = calendar.date(byAdding: .day, value: -offset, to: today)!
                return allDays.contains { calendar.isDate($0.date, inSameDayAs: day) }
            }
            let reading = allBooks
                .filter { $0.shelf == .reading && !$0.isPrivate }
                .sorted { ($0.dateStarted ?? .distantPast) > ($1.dateStarted ?? .distantPast) }
                .prefix(2)
                .map { ReadingStreakEntry.ReadingBookInfo(
                    id: $0.olWorkKey,
                    title: $0.title,
                    authorName: $0.authorName,
                    coverImageID: $0.coverImageID
                )}

            return ReadingStreakEntry(
                date: .now,
                streak: streak,
                readToday: readToday,
                last7Days: last7Days,
                currentlyReading: Array(reading)
            )
        } catch {
            return .empty
        }
    }

}

// MARK: - Widget Definition

struct ReadingStreakWidget: Widget {
    let kind = "ReadingStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingStreakProvider()) { entry in
            ReadingStreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "openshelf://stats"))
        }
        .configurationDisplayName("Reading Streak")
        .description("Track your daily reading streak and mark books as read.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Widget Views

struct ReadingStreakWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: ReadingStreakEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            smallView
        }
    }

    private var streakColor: Color {
        switch entry.streak {
        case 100...: .orange
        case 30..<100: .purple
        case 7..<30: .blue
        default: .green
        }
    }

    // MARK: - Small Widget

    private var smallView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: entry.streak > 0 ? "flame.fill" : "book.fill")
                    .foregroundStyle(entry.streak > 0 ? streakColor : .secondary)
                Text("\(entry.streak)")
                    .font(.system(.title, design: .rounded).bold())
                Text(entry.streak == 1 ? "day" : "days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.streak) day reading streak")

            Spacer(minLength: 0)

            if entry.readToday {
                Label("Read today", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button(intent: MarkReadTodayIntent()) {
                    Label("I read today", systemImage: "book.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(streakColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark as read today")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Medium Widget

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.streak > 0 ? "flame.fill" : "book.fill")
                    .foregroundStyle(entry.streak > 0 ? streakColor : .secondary)
                Text("\(entry.streak) day streak")
                    .font(.system(.headline, design: .rounded).bold())
                Spacer()
                if entry.readToday {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.streak) day reading streak\(entry.readToday ? ", read today" : "")")

            if !entry.currentlyReading.isEmpty {
                ForEach(entry.currentlyReading) { book in
                    bookRow(book)
                }
            } else if !entry.readToday {
                Spacer(minLength: 0)
                Button(intent: MarkReadTodayIntent()) {
                    Label("I read today", systemImage: "book.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(streakColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                Spacer(minLength: 0)
                Label("Keep it up!", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
    }

    private func bookRow(_ book: ReadingStreakEntry.ReadingBookInfo) -> some View {
        HStack(spacing: 8) {
            if let uiImage = loadCoverImage(coverID: book.coverImageID) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                    Image(systemName: "book.closed.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 32, height: 46)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(book.authorName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !entry.readToday {
                Button(intent: makeMarkReadIntent(bookID: book.id)) {
                    Text("Read")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(streakColor.opacity(0.2), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark \(book.title) as read today")
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.body)
            }
        }
    }

    private func loadCoverImage(coverID: Int?) -> UIImage? {
        guard let coverID else { return nil }
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.forddevinc.OpenShelf.shared"
        ) else { return nil }
        let path = groupURL.appendingPathComponent("Covers/\(coverID)_M.jpg")
        return UIImage(contentsOfFile: path.path)
    }

    private func makeMarkReadIntent(bookID: String) -> MarkReadTodayIntent {
        var intent = MarkReadTodayIntent()
        intent.bookID = bookID
        return intent
    }

    // MARK: - Lock Screen Circular

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.streak > 0 ? "flame.fill" : "book.closed")
                    .font(.caption)
                Text("\(entry.streak)")
                    .font(.system(.title3, design: .rounded).bold())
            }
        }
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.streak) day reading streak")
    }

    // MARK: - Lock Screen Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: entry.streak > 0 ? "flame.fill" : "book.closed")
                Text("\(entry.streak) day streak")
                    .font(.headline)
            }
            .widgetAccentable()

            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(entry.last7Days[index] ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
                Spacer(minLength: 0)
                Text("Last 7 days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.streak) day reading streak. Read \(entry.last7Days.filter { $0 }.count) of last 7 days.")
    }
}

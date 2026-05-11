import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct ReadingGoalEntry: TimelineEntry {
    let date: Date
    let booksRead: Int
    let target: Int
    let year: Int
    let streak: Int

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(booksRead) / Double(target), 1.0)
    }

    /// Calculates how many books ahead or behind schedule the reader is.
    var pace: Int {
        let calendar = Calendar.current
        let now = Date.now
        let currentYear = calendar.component(.year, from: now)

        guard currentYear == year, target > 0 else {
            return booksRead - target
        }

        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let totalDays = calendar.range(of: .day, in: .year, for: now)?.count ?? 365
        let expectedBooks = Double(target) * Double(dayOfYear) / Double(totalDays)
        return booksRead - Int(expectedBooks.rounded())
    }

    /// Ring colour based on pace: green (on/ahead), orange (slightly behind), red (far behind).
    var ringColour: Color {
        if pace >= 0 {
            return .green
        } else if pace >= -3 {
            return .orange
        } else {
            return .red
        }
    }

    static var placeholder: ReadingGoalEntry {
        ReadingGoalEntry(
            date: .now,
            booksRead: 23,
            target: 40,
            year: Calendar.current.component(.year, from: .now),
            streak: 12
        )
    }

    static var empty: ReadingGoalEntry {
        ReadingGoalEntry(
            date: .now,
            booksRead: 0,
            target: 0,
            year: Calendar.current.component(.year, from: .now),
            streak: 0
        )
    }
}

// MARK: - Timeline Provider

struct ReadingGoalProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingGoalEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingGoalEntry) -> Void) {
        completion(context.isPreview ? .placeholder : fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingGoalEntry>) -> Void) {
        let entry = fetchEntry()
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }

    private func fetchEntry() -> ReadingGoalEntry {
        let currentYear = Calendar.current.component(.year, from: .now)

        do {
            let context = try WidgetSharedStore.makeContext()

            // Fetch reading goal
            let goalDescriptor = FetchDescriptor<ReadingGoal>(
                predicate: #Predicate { $0.year == currentYear }
            )
            let goals = try context.fetch(goalDescriptor)
            guard let goal = goals.first else {
                return .empty
            }

            // Count books finished this year (excluding private)
            let bookDescriptor = FetchDescriptor<Book>()
            let allBooks = try context.fetch(bookDescriptor)
            let booksRead = allBooks.filter { $0.shelf == .read && !$0.isPrivate }.filter { book in
                guard let date = book.dateFinished else { return false }
                return Calendar.current.component(.year, from: date) == currentYear
            }.count

            let privateKeys = Set(allBooks.filter(\.isPrivate).map(\.olWorkKey))
            let dayDescriptor = FetchDescriptor<ReadingDay>()
            let allDays = (try? context.fetch(dayDescriptor))?.filter { day in
                guard let key = day.bookKey else { return true }
                return !privateKeys.contains(key)
            } ?? []
            let streak = ReadingDay.streak(from: allDays.map(\.date))

            return ReadingGoalEntry(
                date: .now,
                booksRead: booksRead,
                target: goal.target,
                year: currentYear,
                streak: streak
            )
        } catch {
            return .empty
        }
    }

}

// MARK: - Widget Definition

struct ReadingGoalWidget: Widget {
    let kind = "ReadingGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingGoalProvider()) { entry in
            ReadingGoalWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "openshelf://stats"))
        }
        .configurationDisplayName("Reading Goal")
        .description("Track your yearly reading goal progress.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget View

struct ReadingGoalWidgetView: View {
    let entry: ReadingGoalEntry

    var body: some View {
        if entry.target > 0 {
            goalView
        } else {
            noGoalView
        }
    }

    private var goalView: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(entry.ringColour.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(
                        entry.ringColour,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(entry.booksRead) / \(entry.target)")
                        .font(.system(.callout, design: .rounded).bold())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(width: 90, height: 90)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.booksRead) of \(entry.target) books read")
            .accessibilityValue(paceDescription)

            Text("books")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if entry.streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(entry.streak) day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var paceDescription: String {
        if entry.pace >= 0 {
            return "On track"
        } else {
            return "\(abs(entry.pace)) books behind schedule"
        }
    }

    private var noGoalView: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("Set a reading goal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No reading goal set. Open Open Shelf to set a goal.")
    }
}

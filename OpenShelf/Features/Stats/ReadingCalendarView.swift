import SwiftUI
import SwiftData

struct ReadingCalendarView: View {
    @Query private var readingDays: [ReadingDay]
    @Environment(BookRepository.self) private var repository

    private let backfillLimit = 14

    private var readingDateSet: Set<Date> {
        let calendar = Calendar.current
        return Set(readingDays.map { calendar.startOfDay(for: $0.date) })
    }

    private var yearSummary: some View {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: .now)
        let daysThisYear = readingDays.filter {
            calendar.component(.year, from: $0.date) == year
        }.count
        let streak = ReadingDay.streak(from: readingDays.map(\.date))

        return VStack(spacing: 4) {
            Text("\(daysThisYear) day\(daysThisYear == 1 ? "" : "s") read in \(String(year))")
                .font(.title3.bold())
            if streak > 0 {
                Text("Current streak: \(streak) day\(streak == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                yearSummary

                ForEach(monthsToShow(), id: \.self) { month in
                    MonthGridView(
                        month: month,
                        readingDates: readingDateSet,
                        backfillLimit: backfillLimit,
                        onToggle: { date in
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            withAnimation(.spring(duration: 0.3, bounce: 0.5)) {
                                _ = repository.toggleReadingDay(for: date)
                            }
                        }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Reading Calendar")
    }

    private func monthsToShow() -> [Date] {
        let calendar = Calendar.current
        let now = Date.now
        let currentMonth = calendar.dateInterval(of: .month, for: now)!.start

        var months: [Date] = []
        for i in 0..<12 {
            if let month = calendar.date(byAdding: .month, value: -i, to: currentMonth) {
                months.append(month)
            }
        }
        return months
    }
}

// MARK: - Month Grid

private struct MonthGridView: View {
    let month: Date
    let readingDates: Set<Date>
    let backfillLimit: Int
    let onToggle: (Date) -> Void

    @State private var toggledDates: Set<Date> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private var daysReadInMonth: Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: month)!
        var count = 0
        for day in range {
            let date = calendar.date(bySetting: .day, value: day, of: month)!
            let startOfDay = calendar.startOfDay(for: date)
            if readingDates.contains(startOfDay) {
                count += 1
            }
        }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Self.monthFormatter.string(from: month))
                    .font(.headline)
                Spacer()
                let count = daysReadInMonth
                if count > 0 {
                    Text("\(count) day\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let calendar = Calendar.current
            let dayLabels = calendar.veryShortWeekdaySymbols

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(dayLabels.indices, id: \.self) { i in
                    Text(dayLabels[i])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(daysInMonth(), id: \.self) { item in
                    if let date = item.date {
                        let didRead = readingDates.contains(date)
                        let editable = isEditable(date)

                        Circle()
                            .fill(didRead ? Color.orange : Color.primary.opacity(0.1))
                            .frame(width: 24, height: 24)
                            .scaleEffect(toggledDates.contains(date) ? 1.3 : 1.0)
                            .onTapGesture {
                                guard editable else { return }
                                onToggle(date)
                                withAnimation(.spring(duration: 0.3, bounce: 0.5)) {
                                    toggledDates.insert(date)
                                }
                                Task {
                                    try? await Task.sleep(for: .milliseconds(400))
                                    await MainActor.run {
                                        withAnimation { toggledDates.remove(date) }
                                    }
                                }
                            }
                            .opacity(editable ? 1.0 : (didRead ? 0.8 : 0.3))
                            .accessibilityLabel(accessibilityLabel(for: date, didRead: didRead))
                            .accessibilityAddTraits(editable ? .isButton : [])
                            .accessibilityHint(editable ? "Tap to toggle" : "")
                    } else {
                        Color.clear
                            .frame(width: 24, height: 24)
                    }
                }
            }
        }
    }

    private func isEditable(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard date <= today else { return false }
        let daysAgo = calendar.dateComponents([.day], from: date, to: today).day ?? 0
        return daysAgo < backfillLimit
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private func accessibilityLabel(for date: Date, didRead: Bool) -> String {
        let dateStr = Self.dayFormatter.string(from: date)
        return "\(dateStr): \(didRead ? "read" : "did not read")"
    }

    private func daysInMonth() -> [CalendarDay] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: month)!
        let firstDay = calendar.component(.weekday, from: month)
        let firstWeekdayIndex = firstDay - calendar.firstWeekday
        let leadingBlanks = (firstWeekdayIndex + 7) % 7

        var items: [CalendarDay] = []
        for _ in 0..<leadingBlanks {
            items.append(CalendarDay(date: nil))
        }
        for day in range {
            let date = calendar.date(bySetting: .day, value: day, of: month)!
            let startOfDay = calendar.startOfDay(for: date)
            items.append(CalendarDay(date: startOfDay))
        }
        return items
    }
}

private struct CalendarDay: Hashable {
    let date: Date?
}

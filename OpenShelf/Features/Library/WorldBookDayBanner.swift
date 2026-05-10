import SwiftUI

// MARK: - World Book Day Logic

struct WorldBookDay {

    /// Returns the date of World Book Day (first Thursday of March) for a given year.
    static func worldBookDay(year: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = 3
        components.day = 1

        let calendar = Calendar.current
        guard let firstOfMarch = calendar.date(from: components) else { return nil }

        let weekday = calendar.component(.weekday, from: firstOfMarch)
        // weekday: 1 = Sunday, 5 = Thursday
        let daysUntilThursday = (5 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysUntilThursday, to: firstOfMarch)
    }

    /// Returns whether the given date falls within World Book Day week
    /// (Monday before through Sunday after WBD).
    static func isWorldBookDayWeek(date: Date = .now) -> Bool {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        guard let wbd = worldBookDay(year: year) else { return false }

        // Monday before WBD
        let wbdWeekday = calendar.component(.weekday, from: wbd)
        let daysToMonday = (wbdWeekday - 2 + 7) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysToMonday, to: wbd),
              let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return false }

        let startOfMonday = calendar.startOfDay(for: monday)
        let endOfSunday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: sunday))!

        return date >= startOfMonday && date < endOfSunday
    }

    /// Returns the WBD week date range for checking if a book was finished during WBD week.
    static func wbdWeekRange(year: Int) -> ClosedRange<Date>? {
        let calendar = Calendar.current
        guard let wbd = worldBookDay(year: year) else { return nil }

        let wbdWeekday = calendar.component(.weekday, from: wbd)
        let daysToMonday = (wbdWeekday - 2 + 7) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysToMonday, to: wbd),
              let sunday = calendar.date(byAdding: .day, value: 6, to: monday) else { return nil }

        let startOfMonday = calendar.startOfDay(for: monday)
        let endOfSunday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: sunday))!

        return startOfMonday...endOfSunday
    }
}

// MARK: - World Book Day Banner View

struct WorldBookDayBanner: View {
    let books: [Book]

    @AppStorage("wbdBannerDismissedYear") private var dismissedYear: Int = 0

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    private var shouldShow: Bool {
        WorldBookDay.isWorldBookDayWeek() && dismissedYear != currentYear
    }

    var body: some View {
        if shouldShow {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Happy World Book Day!")
                            .font(.headline)
                        Text("Read a book this week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        dismissedYear = currentYear
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    if let url = URL(string: "https://www.worldbookday.com") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Support World Book Day", systemImage: "globe")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.accentColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

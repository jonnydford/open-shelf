import Foundation
import SwiftData

@Model
final class ReadingDay {
    var date: Date
    var bookKey: String?

    init(date: Date = Calendar.current.startOfDay(for: .now), bookKey: String? = nil) {
        self.date = date
        self.bookKey = bookKey
    }

    @MainActor
    static func record(for date: Date = .now, bookKey: String? = nil, in context: ModelContext) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<ReadingDay>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        guard (try? context.fetch(descriptor))?.isEmpty ?? true else { return }
        context.insert(ReadingDay(date: startOfDay, bookKey: bookKey))
    }

    nonisolated static func streak(from dates: [Date]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dateSet = Set(dates.map { calendar.startOfDay(for: $0) })
        guard dateSet.contains(today) || dateSet.contains(yesterday) else { return 0 }
        var count = 0
        var day = dateSet.contains(today) ? today : yesterday
        while dateSet.contains(day) {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
}

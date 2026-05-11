import AppIntents
import SwiftData
import WidgetKit

struct MarkReadTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark as read today"
    static let description: IntentDescription = "Record that you read today to maintain your streak."

    @Parameter(title: "Book ID")
    var bookID: String?

    func perform() async throws -> some IntentResult {
        let context = try WidgetSharedStore.makeContext()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<ReadingDay>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        guard (try? context.fetch(descriptor))?.isEmpty ?? true else {
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }

        context.insert(ReadingDay(date: startOfDay, bookKey: bookID))
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

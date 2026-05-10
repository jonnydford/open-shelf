import AppIntents
import SwiftData

struct GetCurrentStreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Reading Streak"
    static let description: IntentDescription = "Get your current reading streak in days."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.makeContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Book>()
        let allBooks = (try? context.fetch(descriptor)) ?? []
        let nonPrivate = allBooks.filter { !$0.isPrivate }

        let streak = StatsCalculator.currentStreak(from: nonPrivate)

        if streak == 0 {
            return .result(dialog: "You don't have an active reading streak. Start reading to begin one!")
        }

        let dayWord = streak == 1 ? "day" : "days"
        return .result(dialog: "Your current reading streak is \(streak) \(dayWord). Keep it up!")
    }
}

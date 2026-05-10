import AppIntents
import SwiftData

struct GetReadingStatsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Reading Stats"
    static let description: IntentDescription = "Get your reading statistics for the current year."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.makeContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Book>()
        let allBooks = (try? context.fetch(descriptor)) ?? []
        let nonPrivate = allBooks.filter { !$0.isPrivate }

        let currentYear = Calendar.current.component(.year, from: .now)
        let booksRead = StatsCalculator.booksRead(from: nonPrivate, filter: .year(currentYear))
        let totalPages = StatsCalculator.totalPages(booksRead)
        let hours = StatsCalculator.estimatedReadingHours(books: booksRead)

        if booksRead.isEmpty {
            return .result(dialog: "You haven't finished any books in \(currentYear) yet. Keep reading!")
        }

        return .result(dialog: "In \(currentYear), you've read \(booksRead.count) books — \(totalPages) pages, about \(hours) hours of reading.")
    }
}

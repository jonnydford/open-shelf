import AppIntents
import SwiftData

struct GetCurrentlyReadingIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Currently Reading"
    static let description: IntentDescription = "See the books you're currently reading."

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.makeContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Book>()
        let allBooks = (try? context.fetch(descriptor)) ?? []

        let reading = allBooks
            .filter { $0.shelf == .reading && !$0.isPrivate }
            .sorted { ($0.dateStarted ?? .distantPast) > ($1.dateStarted ?? .distantPast) }

        if reading.isEmpty {
            return .result(dialog: "You're not reading any books right now.")
        }

        if reading.count == 1, let book = reading.first {
            var msg = "You're reading \"\(book.title)\" by \(book.authorName)"
            if let current = book.currentPage, let total = book.pageCount, total > 0 {
                let pct = Int(Double(current) / Double(total) * 100)
                msg += " — \(pct)% done"
            }
            msg += "."
            return .result(dialog: "\(msg)")
        }

        let titles = reading.prefix(5).map { "\"\($0.title)\"" }.joined(separator: ", ")
        return .result(dialog: "You're reading \(reading.count) books: \(titles).")
    }
}

import AppIntents
import SwiftData
import WidgetKit

struct LogFinishedBookIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Book as Finished"
    static let description: IntentDescription = "Mark a book as finished reading."

    @Parameter(title: "Book")
    var book: AppBookEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.makeContainer()
        let context = ModelContext(container)

        let foundBook: Book?

        if let selectedBook = book {
            let bookKey = selectedBook.id
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate { $0.olWorkKey == bookKey }
            )
            let result = (try? context.fetch(descriptor))?.first
            foundBook = result?.isPrivate == true ? nil : result
        } else {
            let descriptor = FetchDescriptor<Book>()
            let allBooks = (try? context.fetch(descriptor)) ?? []
            foundBook = allBooks
                .filter { $0.shelf == .reading && !$0.isPrivate }
                .sorted { ($0.dateStarted ?? .distantPast) > ($1.dateStarted ?? .distantPast) }
                .first
        }

        guard let foundBook else {
            return .result(dialog: "No book found to mark as finished.")
        }

        let entry = ReadEntry(
            book: foundBook,
            startDate: foundBook.dateStarted,
            finishDate: .now
        )
        context.insert(entry)

        foundBook.shelf = .read
        if foundBook.dateFinished == nil {
            foundBook.dateFinished = .now
        }
        if let pageCount = foundBook.pageCount {
            foundBook.currentPage = pageCount
        }

        ReadingDay.record(bookKey: foundBook.olWorkKey, in: context)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        SpotlightIndexer.indexBook(foundBook)
        return .result(dialog: "Finished \"\(foundBook.title)\"! Great work.")
    }
}

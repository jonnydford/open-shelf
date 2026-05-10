import AppIntents
import SwiftData
import WidgetKit

struct MarkFinishedIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark as Finished"
    static let description: IntentDescription = "Mark the current book as finished."

    @Parameter(title: "Book ID")
    var bookID: String

    func perform() async throws -> some IntentResult {
        let context = try WidgetSharedStore.makeContext()
        let bookKey = bookID
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.olWorkKey == bookKey }
        )

        guard let book = (try? context.fetch(descriptor))?.first else {
            return .result()
        }

        book.shelf = .read
        if book.dateFinished == nil {
            book.dateFinished = .now
        }
        if let pageCount = book.pageCount {
            book.currentPage = pageCount
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

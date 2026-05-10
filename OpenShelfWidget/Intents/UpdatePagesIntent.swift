import AppIntents
import SwiftData
import WidgetKit

struct UpdatePagesIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Reading Progress"
    static let description: IntentDescription = "Add pages to your current reading progress."

    @Parameter(title: "Book ID")
    var bookID: String

    @Parameter(title: "Pages to Add", default: 10)
    var pagesToAdd: Int

    func perform() async throws -> some IntentResult {
        let context = try WidgetSharedStore.makeContext()
        let bookKey = bookID
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.olWorkKey == bookKey }
        )

        guard let book = (try? context.fetch(descriptor))?.first,
              !book.isPrivate else {
            return .result()
        }

        let currentPage = book.currentPage ?? 0
        let newPage: Int
        if let pageCount = book.pageCount {
            newPage = min(currentPage + pagesToAdd, pageCount)
        } else {
            newPage = currentPage + pagesToAdd
        }
        book.currentPage = newPage

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

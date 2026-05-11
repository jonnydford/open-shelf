import AppIntents
import SwiftData
import WidgetKit

struct UpdateReadingProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Reading Progress"
    static let description: IntentDescription = "Set the current page for a book."

    @Parameter(title: "Book")
    var book: AppBookEntity

    @Parameter(title: "Page")
    var page: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try SharedModelContainer.makeContainer()
        let context = ModelContext(container)
        let bookKey = book.id
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.olWorkKey == bookKey }
        )

        guard let foundBook = (try? context.fetch(descriptor))?.first,
              !foundBook.isPrivate else {
            return .result(dialog: "Could not find that book in your library.")
        }

        let clampedPage: Int
        if let pageCount = foundBook.pageCount {
            clampedPage = min(max(page, 0), pageCount)
        } else {
            clampedPage = max(page, 0)
        }

        foundBook.currentPage = clampedPage

        if foundBook.shelf == .wantToRead {
            foundBook.shelf = .reading
            foundBook.dateStarted = .now
        }

        ReadingDay.record(bookKey: foundBook.olWorkKey, in: context)
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        if let pageCount = foundBook.pageCount {
            let pct = Int(Double(clampedPage) / Double(pageCount) * 100)
            return .result(dialog: "\"\(foundBook.title)\" — page \(clampedPage) of \(pageCount) (\(pct)%).")
        }
        return .result(dialog: "\"\(foundBook.title)\" — page \(clampedPage).")
    }
}

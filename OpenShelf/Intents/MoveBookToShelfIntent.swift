import AppIntents
import SwiftData
import WidgetKit

struct MoveBookToShelfIntent: AppIntent {
    static let title: LocalizedStringResource = "Move Book to Shelf"
    static let description: IntentDescription = "Move a book to a different shelf."

    @Parameter(title: "Book")
    var book: AppBookEntity

    @Parameter(title: "Shelf")
    var shelf: ShelfAppEnum

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

        let targetShelf = shelf.shelf
        foundBook.shelf = targetShelf

        switch targetShelf {
        case .reading:
            if foundBook.dateStarted == nil {
                foundBook.dateStarted = .now
            }
        case .read:
            if foundBook.dateFinished == nil {
                foundBook.dateFinished = .now
            }
            let entry = ReadEntry(
                book: foundBook,
                startDate: foundBook.dateStarted,
                finishDate: .now
            )
            context.insert(entry)
        case .wantToRead:
            foundBook.dateStarted = nil
            foundBook.dateFinished = nil
            foundBook.currentPage = nil
        case .dnf:
            break
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
        SpotlightIndexer.indexBook(foundBook)
        return .result(dialog: "Moved \"\(foundBook.title)\" to \(targetShelf.displayName).")
    }
}

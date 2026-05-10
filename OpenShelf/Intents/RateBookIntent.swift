import AppIntents
import SwiftData

struct RateBookIntent: AppIntent {
    static let title: LocalizedStringResource = "Rate a Book"
    static let description: IntentDescription = "Set a star rating on a book."

    @Parameter(title: "Book")
    var book: AppBookEntity

    @Parameter(title: "Rating", inclusiveRange: (0.5, 5.0))
    var rating: Double

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

        foundBook.userRating = rating
        try? context.save()

        let stars = String(format: "%.1f", rating)
        return .result(dialog: "Rated \"\(foundBook.title)\" \(stars) stars.")
    }
}

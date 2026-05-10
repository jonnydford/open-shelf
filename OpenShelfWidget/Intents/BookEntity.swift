import AppIntents
import SwiftData

struct BookEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Book")
    static let defaultQuery = BookEntityQuery()

    var id: String
    var title: String
    var authorName: String
    var coverImageID: Int?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(authorName)")
    }
}

struct BookEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [BookEntity] {
        let context = try WidgetSharedStore.makeContext()
        let descriptor = FetchDescriptor<Book>()
        let books = (try? context.fetch(descriptor)) ?? []
        return books
            .filter { identifiers.contains($0.olWorkKey) && !$0.isPrivate }
            .map { BookEntity(id: $0.olWorkKey, title: $0.title, authorName: $0.authorName, coverImageID: $0.coverImageID) }
    }

    func suggestedEntities() async throws -> [BookEntity] {
        let context = try WidgetSharedStore.makeContext()
        let descriptor = FetchDescriptor<Book>()
        let books = (try? context.fetch(descriptor)) ?? []
        return books
            .filter { $0.shelf == .reading && !$0.isPrivate }
            .sorted { ($0.dateStarted ?? .distantPast) > ($1.dateStarted ?? .distantPast) }
            .map { BookEntity(id: $0.olWorkKey, title: $0.title, authorName: $0.authorName, coverImageID: $0.coverImageID) }
    }
}

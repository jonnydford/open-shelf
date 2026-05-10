import AppIntents
import SwiftData

struct AppBookEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Book")
    static let defaultQuery = AppBookEntityQuery()

    var id: String
    var title: String
    var authorName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(authorName)")
    }
}

struct AppBookEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [AppBookEntity] {
        let container = try SharedModelContainer.makeContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Book>()
        let books = (try? context.fetch(descriptor)) ?? []
        return books
            .filter { identifiers.contains($0.olWorkKey) }
            .map { AppBookEntity(id: $0.olWorkKey, title: $0.title, authorName: $0.authorName) }
    }

    @MainActor
    func entities(matching string: String) async throws -> [AppBookEntity] {
        let container = try SharedModelContainer.makeContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Book>()
        let books = (try? context.fetch(descriptor)) ?? []
        let query = string.lowercased()
        return books
            .filter {
                $0.title.lowercased().contains(query) ||
                $0.authorName.lowercased().contains(query)
            }
            .map { AppBookEntity(id: $0.olWorkKey, title: $0.title, authorName: $0.authorName) }
    }

    @MainActor
    func suggestedEntities() async throws -> [AppBookEntity] {
        let container = try SharedModelContainer.makeContainer()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Book>()
        let books = (try? context.fetch(descriptor)) ?? []
        return books
            .sorted { ($0.dateStarted ?? $0.dateAdded) > ($1.dateStarted ?? $1.dateAdded) }
            .prefix(20)
            .map { AppBookEntity(id: $0.olWorkKey, title: $0.title, authorName: $0.authorName) }
    }
}

import CoreSpotlight
import SwiftData
import UIKit

@MainActor
final class SpotlightIndexer {
    private static let bookDomain = "com.openshelf.book"
    private static let listDomain = "com.openshelf.readinglist"

    static func indexAllBooks(from context: ModelContext) {
        let descriptor = FetchDescriptor<Book>()
        guard let books = try? context.fetch(descriptor) else { return }

        let publicBooks = books.filter { !$0.isPrivate }

        let items = publicBooks.map { searchableItem(for: $0) }

        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [bookDomain]) { _ in
            index.indexSearchableItems(items) { _ in }
        }
    }

    static func indexBook(_ book: Book) {
        guard !book.isPrivate else {
            removeBook(book)
            return
        }
        let item = searchableItem(for: book)
        CSSearchableIndex.default().indexSearchableItems([item]) { _ in }
    }

    static func removeBook(_ book: Book) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [book.olWorkKey]
        ) { _ in }
    }

    static func indexAllLists(from context: ModelContext) {
        let descriptor = FetchDescriptor<ReadingList>()
        guard let lists = try? context.fetch(descriptor) else { return }

        let items = lists.map { searchableItem(for: $0) }

        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [listDomain]) { _ in
            index.indexSearchableItems(items) { _ in }
        }
    }

    static func indexList(_ list: ReadingList) {
        let item = searchableItem(for: list)
        CSSearchableIndex.default().indexSearchableItems([item]) { _ in }
    }

    static func removeList(_ list: ReadingList) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [list.id.uuidString]
        ) { _ in }
    }

    // MARK: - Private

    private static func searchableItem(for book: Book) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = book.title
        attributes.contentDescription = book.authorName
        attributes.identifier = book.olWorkKey

        if let isbn = book.isbn13 {
            attributes.alternateNames = [isbn]
        }

        if !book.subjects.isEmpty {
            attributes.keywords = Array(book.subjects.prefix(10))
        }

        attributes.information = book.shelf.displayName

        if let coverID = book.coverImageID {
            let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.openshelf.shared"
            )
            if let url = groupURL?.appendingPathComponent("Covers/\(coverID)_M.jpg"),
               FileManager.default.fileExists(atPath: url.path) {
                attributes.thumbnailURL = url
            }
        }

        let item = CSSearchableItem(
            uniqueIdentifier: book.olWorkKey,
            domainIdentifier: bookDomain,
            attributeSet: attributes
        )
        item.expirationDate = .distantFuture
        return item
    }

    private static func searchableItem(for list: ReadingList) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = list.name
        attributes.contentDescription = "\(list.bookKeys.count) books"
        attributes.identifier = list.id.uuidString

        let item = CSSearchableItem(
            uniqueIdentifier: list.id.uuidString,
            domainIdentifier: listDomain,
            attributeSet: attributes
        )
        item.expirationDate = .distantFuture
        return item
    }
}

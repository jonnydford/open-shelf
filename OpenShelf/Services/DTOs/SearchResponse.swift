import Foundation

struct SearchResponse: Codable, Sendable {
    let numFound: Int
    let start: Int
    let docs: [SearchResult]
}

struct SearchResult: Codable, Sendable, Identifiable, Hashable {
    let key: String
    let title: String
    let authorName: [String]?
    let firstPublishYear: Int?
    let numberOfPagesMedian: Int?
    let coverI: Int?
    let editionCount: Int?
    let isbn: [String]?
    let subject: [String]?
    let idGoodreads: [String]?

    var id: String { key }

    var primaryAuthor: String {
        authorName?.first ?? "Unknown Author"
    }

    var primaryISBN13: String? {
        isbn?.first { $0.count == 13 }
    }

    var primaryISBN10: String? {
        isbn?.first { $0.count == 10 }
    }

    var primaryGoodreadsID: String? {
        idGoodreads?.first
    }

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case numberOfPagesMedian = "number_of_pages_median"
        case coverI = "cover_i"
        case editionCount = "edition_count"
        case isbn
        case subject
        case idGoodreads = "id_goodreads"
    }
}

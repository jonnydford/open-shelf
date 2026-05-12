import Foundation

struct SubjectResponse: Codable, Sendable {
    let key: String
    let name: String
    let workCount: Int
    let works: [SubjectWork]

    enum CodingKeys: String, CodingKey {
        case key
        case name
        case workCount = "work_count"
        case works
    }
}

struct SubjectWork: Codable, Sendable, Identifiable, Hashable {
    let key: String
    let title: String
    let editionCount: Int?
    let coverID: Int?
    let subject: [String]?
    let authors: [SubjectAuthor]?
    let firstPublishYear: Int?

    var id: String { key }

    var primaryAuthor: String {
        authors?.first?.name ?? "Unknown Author"
    }

    var asSearchResult: SearchResult {
        SearchResult(
            key: key,
            title: title,
            authorName: authors?.map(\.name),
            firstPublishYear: firstPublishYear,
            numberOfPagesMedian: nil,
            coverI: coverID,
            editionCount: editionCount,
            isbn: nil,
            subject: subject,
            idGoodreads: nil
        )
    }

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case editionCount = "edition_count"
        case coverID = "cover_id"
        case subject
        case authors
        case firstPublishYear = "first_publish_year"
    }
}

struct SubjectAuthor: Codable, Sendable, Identifiable, Hashable {
    let key: String
    let name: String

    var id: String { key }
}

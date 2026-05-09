import Foundation

struct EditionDetail: Codable, Sendable {
    let key: String
    let title: String
    let publishers: [String]?
    let numberOfPages: Int?
    let isbn13: [String]?
    let isbn10: [String]?
    let covers: [Int]?
    let languages: [LanguageRef]?
    let works: [WorkRef]?

    var primaryISBN13: String? {
        isbn13?.first
    }

    var primaryISBN10: String? {
        isbn10?.first
    }

    var primaryPublisher: String? {
        publishers?.first
    }

    var primaryCoverID: Int? {
        covers?.first
    }

    var primaryLanguage: String? {
        languages?.first?.key.replacingOccurrences(of: "/languages/", with: "")
    }

    var workKey: String? {
        works?.first?.key
    }

    struct LanguageRef: Codable, Sendable {
        let key: String
    }

    struct WorkRef: Codable, Sendable {
        let key: String
    }

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case publishers
        case numberOfPages = "number_of_pages"
        case isbn13 = "isbn_13"
        case isbn10 = "isbn_10"
        case covers
        case languages
        case works
    }
}

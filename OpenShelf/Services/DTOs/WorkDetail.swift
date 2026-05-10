import Foundation

struct WorkDetail: Codable, Sendable {
    let key: String
    let title: String
    let description: DescriptionValue?
    let subjects: [String]?
    let covers: [Int]?
    let firstPublishDate: String?
    let authors: [AuthorRef]?

    var synopsis: String? {
        description?.text
    }

    var primaryCoverID: Int? {
        covers?.first
    }

    var primaryAuthorKey: String? {
        authors?.first?.author?.key
    }

    struct AuthorRef: Codable, Sendable {
        let author: AuthorKey?
        struct AuthorKey: Codable, Sendable {
            let key: String
        }
    }

    enum CodingKeys: String, CodingKey {
        case key
        case title
        case description
        case subjects
        case covers
        case authors
        case firstPublishDate = "first_publish_date"
    }
}

/// Open Library returns description as either a plain string or an object
/// with `type` and `value` keys. This type handles both.
enum DescriptionValue: Codable, Sendable {
    case text(String)
    case typed(TypedValue)

    struct TypedValue: Codable, Sendable {
        let type: String
        let value: String
    }

    var text: String {
        switch self {
        case .text(let string):
            return string
        case .typed(let typed):
            return typed.value
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .text(string)
        } else {
            let typed = try container.decode(TypedValue.self)
            self = .typed(typed)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .typed(let typed):
            try container.encode(typed)
        }
    }
}

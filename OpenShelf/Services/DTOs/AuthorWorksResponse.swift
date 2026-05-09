import Foundation

struct AuthorWorksResponse: Codable, Sendable {
    let entries: [AuthorWork]

    struct AuthorWork: Codable, Sendable {
        let key: String
        let title: String
        let created: WorkDate?
    }

    struct WorkDate: Codable, Sendable {
        let value: String
    }
}

import Foundation

struct WorkRatings: Codable, Sendable {
    let summary: RatingSummary
    let counts: RatingCounts

    struct RatingSummary: Codable, Sendable {
        let average: Double
        let count: Int
    }

    struct RatingCounts: Codable, Sendable {
        let one: Int
        let two: Int
        let three: Int
        let four: Int
        let five: Int

        enum CodingKeys: String, CodingKey {
            case one = "1"
            case two = "2"
            case three = "3"
            case four = "4"
            case five = "5"
        }
    }
}

struct WorkBookshelves: Codable, Sendable {
    let counts: BookshelfCounts

    struct BookshelfCounts: Codable, Sendable {
        let wantToRead: Int
        let currentlyReading: Int
        let alreadyRead: Int

        enum CodingKeys: String, CodingKey {
            case wantToRead = "want_to_read"
            case currentlyReading = "currently_reading"
            case alreadyRead = "already_read"
        }
    }
}

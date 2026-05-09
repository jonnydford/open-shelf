import Foundation
import SwiftData

@Model
final class ReadingList {
    var id: UUID
    var name: String
    var bookKeys: [String]  // olWorkKey references
    var dateCreated: Date
    var includeRatings: Bool
    var includeNotes: Bool

    init(
        id: UUID = UUID(),
        name: String,
        bookKeys: [String] = [],
        dateCreated: Date = .now,
        includeRatings: Bool = true,
        includeNotes: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bookKeys = bookKeys
        self.dateCreated = dateCreated
        self.includeRatings = includeRatings
        self.includeNotes = includeNotes
    }
}

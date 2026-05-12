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
    var ckRecordName: String?

    init(
        id: UUID = UUID(),
        name: String,
        bookKeys: [String] = [],
        dateCreated: Date = .now,
        includeRatings: Bool = true,
        includeNotes: Bool = false,
        ckRecordName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.bookKeys = bookKeys
        self.dateCreated = dateCreated
        self.includeRatings = includeRatings
        self.includeNotes = includeNotes
        self.ckRecordName = ckRecordName
    }

    func toggleBook(key: String) {
        if bookKeys.contains(key) {
            bookKeys.removeAll { $0 == key }
        } else {
            bookKeys.append(key)
        }
    }
}

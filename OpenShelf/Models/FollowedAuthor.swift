import Foundation
import SwiftData

@Model
final class FollowedAuthor {
    var authorName: String
    var olAuthorKey: String?
    var lastCheckedDate: Date?
    var lastKnownWorkKey: String?
    var dateFollowed: Date

    init(
        authorName: String,
        olAuthorKey: String? = nil,
        dateFollowed: Date = .now
    ) {
        self.authorName = authorName
        self.olAuthorKey = olAuthorKey
        self.dateFollowed = dateFollowed
    }
}

import Foundation
import SwiftData

@Model
final class FollowedShelf {
    var id: UUID
    var ownerRecordName: String
    var displayName: String
    var lastFetched: Date
    var cachedSnapshot: Data?

    init(
        id: UUID = UUID(),
        ownerRecordName: String,
        displayName: String,
        lastFetched: Date = .now,
        cachedSnapshot: Data? = nil
    ) {
        self.id = id
        self.ownerRecordName = ownerRecordName
        self.displayName = displayName
        self.lastFetched = lastFetched
        self.cachedSnapshot = cachedSnapshot
    }

    var decodedSnapshot: PublicShelfSnapshot? {
        guard let data = cachedSnapshot else { return nil }
        return try? JSONDecoder().decode(PublicShelfSnapshot.self, from: data)
    }

    var isStale: Bool {
        Date.now.timeIntervalSince(lastFetched) > 24 * 60 * 60
    }
}

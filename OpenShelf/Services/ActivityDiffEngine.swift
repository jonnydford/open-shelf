import Foundation

enum ActivityDiffEngine {
    static func diff(
        old: PublicShelfSnapshot?,
        new: PublicShelfSnapshot,
        friendDisplayName: String,
        friendRecordName: String
    ) -> [ActivityEvent] {
        guard let old else { return [] }

        var events: [ActivityEvent] = []
        let oldReadingKeys = Set(old.currentlyReading.map(\.olWorkKey))
        let oldFinishedKeys = Set(old.recentlyFinished.map(\.olWorkKey))

        for book in new.currentlyReading where !oldReadingKeys.contains(book.olWorkKey) && !oldFinishedKeys.contains(book.olWorkKey) {
            events.append(ActivityEvent(
                friendDisplayName: friendDisplayName,
                friendRecordName: friendRecordName,
                eventType: "started",
                bookTitle: book.title,
                bookAuthor: book.authorName,
                bookCoverID: book.coverImageID,
                bookWorkKey: book.olWorkKey
            ))
        }

        for book in new.recentlyFinished where !oldFinishedKeys.contains(book.olWorkKey) {
            events.append(ActivityEvent(
                friendDisplayName: friendDisplayName,
                friendRecordName: friendRecordName,
                eventType: "finished",
                bookTitle: book.title,
                bookAuthor: book.authorName,
                bookCoverID: book.coverImageID,
                bookWorkKey: book.olWorkKey,
                rating: book.rating
            ))
        }

        let oldRatings = Dictionary(
            uniqueKeysWithValues: (old.currentlyReading + old.recentlyFinished)
                .compactMap { book in book.rating.map { (book.olWorkKey, $0) } }
        )
        for book in (new.currentlyReading + new.recentlyFinished) {
            guard let rating = book.rating, oldRatings[book.olWorkKey] == nil else { continue }
            let alreadyHasFinished = events.contains { $0.bookWorkKey == book.olWorkKey && $0.eventType == "finished" }
            if alreadyHasFinished { continue }
            events.append(ActivityEvent(
                friendDisplayName: friendDisplayName,
                friendRecordName: friendRecordName,
                eventType: "rated",
                bookTitle: book.title,
                bookAuthor: book.authorName,
                bookCoverID: book.coverImageID,
                bookWorkKey: book.olWorkKey,
                rating: rating
            ))
        }

        if let newGoal = new.goalProgress, let oldGoal = old.goalProgress {
            let newHit = newGoal.contains("100%") || newGoal.lowercased().contains("reached")
            let oldHit = oldGoal.contains("100%") || oldGoal.lowercased().contains("reached")
            if newHit && !oldHit {
                events.append(ActivityEvent(
                    friendDisplayName: friendDisplayName,
                    friendRecordName: friendRecordName,
                    eventType: "goal",
                    bookTitle: "",
                    bookAuthor: ""
                ))
            }
        }

        return events
    }
}

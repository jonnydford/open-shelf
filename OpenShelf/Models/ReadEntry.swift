import Foundation
import SwiftData

@Model
final class ReadEntry {
    var book: Book?
    var startDate: Date?
    var finishDate: Date?
    var rating: Double?
    var notes: String?
    var dnfPage: Int?
    var dnfReason: String?

    init(
        book: Book? = nil,
        startDate: Date? = nil,
        finishDate: Date? = nil,
        rating: Double? = nil,
        notes: String? = nil,
        dnfPage: Int? = nil,
        dnfReason: String? = nil
    ) {
        self.book = book
        self.startDate = startDate
        self.finishDate = finishDate
        self.rating = rating
        self.notes = notes
        self.dnfPage = dnfPage
        self.dnfReason = dnfReason
    }
}

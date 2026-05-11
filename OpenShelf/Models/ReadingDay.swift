import Foundation
import SwiftData

@Model
final class ReadingDay {
    var date: Date
    var bookKey: String?

    init(date: Date = Calendar.current.startOfDay(for: .now), bookKey: String? = nil) {
        self.date = date
        self.bookKey = bookKey
    }
}

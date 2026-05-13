import Foundation
import SwiftData

@Model
final class DismissedBook {
    var openLibraryWorkKey: String = ""
    var title: String = ""
    var author: String = ""
    var dateDismissed: Date = Date.now

    init(
        openLibraryWorkKey: String,
        title: String,
        author: String,
        dateDismissed: Date = .now
    ) {
        self.openLibraryWorkKey = openLibraryWorkKey
        self.title = title
        self.author = author
        self.dateDismissed = dateDismissed
    }
}

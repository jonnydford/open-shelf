import Foundation
import SwiftData

enum SmartList: String, CaseIterable, Identifiable {
    case fiveStarBooks
    case favourites
    case readThisYear
    case shortReads
    case unrated

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fiveStarBooks: "5-Star Books"
        case .favourites: "My Favourites"
        case .readThisYear: "Read This Year"
        case .shortReads: "Short Reads"
        case .unrated: "Unrated"
        }
    }

    var systemImage: String {
        switch self {
        case .fiveStarBooks: "star.fill"
        case .favourites: "heart.fill"
        case .readThisYear: "calendar"
        case .shortReads: "book.pages"
        case .unrated: "star.slash"
        }
    }

    var subtitle: String {
        switch self {
        case .fiveStarBooks: "Books you rated 5 stars"
        case .favourites: "Your favourited books"
        case .readThisYear: "Books finished this year"
        case .shortReads: "Want to Read under 200 pages"
        case .unrated: "Read books without a rating"
        }
    }

    func matches(_ book: Book) -> Bool {
        switch self {
        case .fiveStarBooks:
            return book.userRating == 5.0
        case .favourites:
            return book.isFavourite
        case .readThisYear:
            guard let finished = book.dateFinished else { return false }
            return Calendar.current.isDate(finished, equalTo: .now, toGranularity: .year)
        case .shortReads:
            guard let pages = book.pageCount else { return false }
            return pages <= 200 && book.shelf == .wantToRead
        case .unrated:
            return book.shelf == .read && book.userRating == nil
        }
    }
}

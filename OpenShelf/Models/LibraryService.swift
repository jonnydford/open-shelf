import Foundation

enum LibraryService: String, CaseIterable, Identifiable {
    case libby = "Libby"
    case borrowBox = "BorrowBox"
    case worldCat = "WorldCat"
    case custom = "Custom"

    var id: String { rawValue }

    func url(for isbn: String) -> URL? {
        switch self {
        case .libby:
            URL(string: "https://libbyapp.com/search/query-\(isbn)")
        case .borrowBox:
            URL(string: "https://www.borrowbox.com/search?query=\(isbn)")
        case .worldCat:
            URL(string: "https://www.worldcat.org/isbn/\(isbn)")
        case .custom:
            nil // handled separately with user's template
        }
    }

    static func customURL(template: String, isbn: String) -> URL? {
        let urlString = template.replacingOccurrences(of: "{isbn}", with: isbn)
        return URL(string: urlString)
    }
}

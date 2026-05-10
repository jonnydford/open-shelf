import Foundation

enum LibraryService: String, CaseIterable, Identifiable {
    case libby = "Libby"
    case borrowBox = "BorrowBox"
    case spydusCloud = "Spydus Cloud"
    case koha = "Koha"
    case jiscLibraryHub = "Jisc Library Hub"
    case worldCat = "WorldCat"
    case custom = "Custom"

    var id: String { rawValue }

    func url(for isbn: String) -> URL? {
        switch self {
        case .libby:
            URL(string: "https://libbyapp.com/search/query-\(isbn)")
        case .borrowBox:
            URL(string: "https://www.borrowbox.com/search?query=\(isbn)")
        case .spydusCloud:
            nil // handled separately with user's slug
        case .koha:
            nil // handled separately with user's domain
        case .jiscLibraryHub:
            URL(string: "https://discover.libraryhub.jisc.ac.uk/search?isbn=\(isbn)")
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

    static func spydusCloudURL(slug: String, isbn: String) -> URL? {
        guard !slug.isEmpty else { return nil }
        let cleaned = slug
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        guard !cleaned.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "prism.librarymanagementcloud.co.uk"
        components.path = "/\(cleaned)/items"
        components.queryItems = [URLQueryItem(name: "query", value: isbn)]
        return components.url
    }

    static func kohaURL(domain: String, isbn: String) -> URL? {
        guard !domain.isEmpty else { return nil }
        var cleaned = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip accidental scheme prefix
        for prefix in ["https://", "http://"] {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }
        // Strip trailing slashes
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !cleaned.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = cleaned
        components.path = "/cgi-bin/koha/opac-search.pl"
        components.queryItems = [URLQueryItem(name: "q", value: "nb:\(isbn)")]
        return components.url
    }
}

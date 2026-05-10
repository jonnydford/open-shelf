import Foundation

/// Identifies a book from a parsed URL or text input.
enum ParsedBookIdentifier: Sendable, Equatable {
    case isbn(String)
    case openLibraryWork(String)
    case openLibraryEdition(String)
    case searchQuery(String)
}

/// Parses book identifiers from URLs shared via the share extension.
///
/// Supports Amazon, Goodreads, Waterstones, Bookshop.org, Open Library,
/// and generic URLs containing ISBN-10 or ISBN-13 in their path.
enum BookURLParser {

    /// Attempts to extract a book identifier from the given input string.
    /// If the string is a valid URL it is parsed for known retailer patterns;
    /// otherwise it is treated as a plain-text search query.
    static func parse(_ input: String) -> ParsedBookIdentifier {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmed),
              let host = url.host?.lowercased(),
              url.scheme == "http" || url.scheme == "https" else {
            // Plain text — use as search query
            return .searchQuery(trimmed)
        }

        let path = url.path

        // Open Library
        if host.contains("openlibrary.org") {
            return parseOpenLibrary(path: path)
        }

        // Amazon (co.uk, .com, .de, etc.)
        if host.contains("amazon.") {
            if let asin = parseAmazon(path: path) {
                return asin
            }
        }

        // Goodreads
        if host.contains("goodreads.com") {
            if let id = parseGoodreads(path: path) {
                return id
            }
        }

        // Waterstones
        if host.contains("waterstones.com") {
            if let isbn = extractISBN13(from: path) {
                return .isbn(isbn)
            }
        }

        // Bookshop.org
        if host.contains("bookshop.org") {
            if let isbn = extractISBN13(from: path) {
                return .isbn(isbn)
            }
        }

        // Generic: look for ISBN-13 or ISBN-10 anywhere in the path
        if let isbn = extractISBN13(from: path) {
            return .isbn(isbn)
        }
        if let isbn10 = extractISBN10(from: path) {
            return .isbn(isbn10)
        }

        // Fallback: use the URL as a search query
        return .searchQuery(trimmed)
    }

    // MARK: - Open Library

    private static func parseOpenLibrary(path: String) -> ParsedBookIdentifier {
        // /works/OL12345W
        if let range = path.range(of: #"/(works/OL\d+W)"#, options: .regularExpression) {
            let key = "/" + String(path[range]).dropFirst(1)
            return .openLibraryWork(String(key))
        }
        // /books/OL12345M
        if let range = path.range(of: #"/(books/OL\d+M)"#, options: .regularExpression) {
            let key = "/" + String(path[range]).dropFirst(1)
            return .openLibraryEdition(String(key))
        }
        // /isbn/1234567890 or /isbn/1234567890123
        if let range = path.range(of: #"/isbn/(\d{10,13})"#, options: .regularExpression) {
            let match = String(path[range])
            let isbn = match.replacingOccurrences(of: "/isbn/", with: "")
            return .isbn(isbn)
        }
        return .searchQuery(path)
    }

    // MARK: - Amazon

    private static func parseAmazon(path: String) -> ParsedBookIdentifier? {
        // /dp/ASIN or /gp/product/ASIN — ASIN is 10 characters (alphanumeric)
        let patterns = [
            #"/dp/([A-Z0-9]{10})"#,
            #"/gp/product/([A-Z0-9]{10})"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let nsPath = path as NSString
            if let match = regex.firstMatch(in: path, range: NSRange(location: 0, length: nsPath.length)) {
                let asin = nsPath.substring(with: match.range(at: 1))
                // ASINs that start with a digit are usually ISBN-10
                if let first = asin.first, first.isNumber {
                    return .isbn(asin)
                }
                // Non-numeric ASIN — search by it
                return .searchQuery(asin)
            }
        }
        return nil
    }

    // MARK: - Goodreads

    private static func parseGoodreads(path: String) -> ParsedBookIdentifier? {
        // /book/show/12345-slug or /book/show/12345.slug or /book/show/12345
        guard let regex = try? NSRegularExpression(
            pattern: #"/book/show/(\d+)"#,
            options: []
        ) else { return nil }

        let nsPath = path as NSString
        if let match = regex.firstMatch(in: path, range: NSRange(location: 0, length: nsPath.length)) {
            let bookID = nsPath.substring(with: match.range(at: 1))
            // Search Goodreads book ID via Open Library
            return .searchQuery("goodreads:\(bookID)")
        }
        return nil
    }

    // MARK: - ISBN extraction

    /// Extracts a 13-digit ISBN from a URL path.
    private static func extractISBN13(from path: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(\d{13})"#,
            options: []
        ) else { return nil }

        let nsPath = path as NSString
        if let match = regex.firstMatch(in: path, range: NSRange(location: 0, length: nsPath.length)) {
            let candidate = nsPath.substring(with: match.range(at: 1))
            if candidate.hasPrefix("978") || candidate.hasPrefix("979") {
                return candidate
            }
        }
        return nil
    }

    /// Extracts a 10-digit ISBN from a URL path (must be surrounded by non-digit characters or string boundaries).
    private static func extractISBN10(from path: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?<!\d)(\d{9}[\dXx])(?!\d)"#,
            options: []
        ) else { return nil }

        let nsPath = path as NSString
        if let match = regex.firstMatch(in: path, range: NSRange(location: 0, length: nsPath.length)) {
            return nsPath.substring(with: match.range(at: 1))
        }
        return nil
    }
}

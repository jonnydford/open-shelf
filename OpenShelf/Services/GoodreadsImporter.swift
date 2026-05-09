import Foundation

// MARK: - CSV Parser

struct CSVParser {
    /// Parse CSV data into an array of rows, each row being an array of field strings.
    /// Handles quoted fields, commas inside quotes, and newlines inside quotes.
    static func parse(_ data: Data) throws -> [[String]] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidCSV
        }
        return try parse(text)
    }

    static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]

            if insideQuotes {
                if char == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex && text[nextIndex] == "\"" {
                        // Escaped quote ("")
                        currentField.append("\"")
                        index = text.index(after: nextIndex)
                    } else {
                        // End of quoted field
                        insideQuotes = false
                        index = text.index(after: index)
                    }
                } else {
                    currentField.append(char)
                    index = text.index(after: index)
                }
            } else {
                if char == "\"" {
                    insideQuotes = true
                    index = text.index(after: index)
                } else if char == "," {
                    currentRow.append(currentField)
                    currentField = ""
                    index = text.index(after: index)
                } else if char == "\r" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex && text[nextIndex] == "\n" {
                        // CRLF
                        currentRow.append(currentField)
                        currentField = ""
                        rows.append(currentRow)
                        currentRow = []
                        index = text.index(after: nextIndex)
                    } else {
                        // Bare CR
                        currentRow.append(currentField)
                        currentField = ""
                        rows.append(currentRow)
                        currentRow = []
                        index = text.index(after: index)
                    }
                } else if char == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    index = text.index(after: index)
                } else {
                    currentField.append(char)
                    index = text.index(after: index)
                }
            }
        }

        // Handle the last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}

// MARK: - Goodreads Row

struct GoodreadsRow: Sendable {
    let title: String
    let author: String
    let isbn: String?
    let isbn13: String?
    let myRating: Double?
    let dateRead: Date?
    let dateAdded: Date?
    let bookshelf: String?
    let myReview: String?
    let numberOfPages: Int?
}

// MARK: - Goodreads Importer

struct GoodreadsImporter: Sendable {

    /// Parse Goodreads CSV data into structured rows.
    static func parseCSV(_ data: Data) throws -> [GoodreadsRow] {
        let rows = try CSVParser.parse(data)

        guard let header = rows.first, !header.isEmpty else {
            throw ImportError.invalidCSV
        }

        // Build column index map (case-insensitive, trimmed)
        var columnMap: [String: Int] = [:]
        for (index, name) in header.enumerated() {
            columnMap[name.trimmingCharacters(in: .whitespaces).lowercased()] = index
        }

        // Validate required columns
        guard columnMap["title"] != nil, columnMap["author"] != nil else {
            throw ImportError.parsingFailed("CSV is missing required Title or Author columns.")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy/MM/dd"

        let altDateFormatter = DateFormatter()
        altDateFormatter.locale = Locale(identifier: "en_US_POSIX")
        altDateFormatter.dateFormat = "yyyy-MM-dd"

        var parsed: [GoodreadsRow] = []

        for rowIndex in 1..<rows.count {
            let fields = rows[rowIndex]
            guard !fields.isEmpty else { continue }
            // Skip rows that are entirely empty
            let nonEmpty = fields.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard nonEmpty != nil else { continue }

            func field(_ name: String) -> String? {
                guard let idx = columnMap[name], idx < fields.count else { return nil }
                let value = fields[idx].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }

            guard let title = field("title"), let author = field("author") else {
                continue // Skip rows without title/author
            }

            let isbn = cleanISBN(field("isbn"))
            let isbn13 = cleanISBN(field("isbn13"))

            let myRating: Double? = {
                guard let str = field("my rating"), let val = Double(str), val > 0 else { return nil }
                return val
            }()

            let dateRead = parseDate(field("date read"), primary: dateFormatter, alt: altDateFormatter)
            let dateAdded = parseDate(field("date added"), primary: dateFormatter, alt: altDateFormatter)

            let bookshelf = field("bookshelves") ?? field("exclusive shelf")

            let myReview = field("my review")

            let numberOfPages: Int? = {
                guard let str = field("number of pages") else { return nil }
                return Int(str)
            }()

            parsed.append(GoodreadsRow(
                title: title,
                author: author,
                isbn: isbn,
                isbn13: isbn13,
                myRating: myRating,
                dateRead: dateRead,
                dateAdded: dateAdded,
                bookshelf: bookshelf,
                myReview: myReview,
                numberOfPages: numberOfPages
            ))
        }

        if parsed.isEmpty {
            throw ImportError.parsingFailed("No valid book rows found in CSV.")
        }

        return parsed
    }

    /// Map Goodreads shelf name to our Shelf enum.
    static func mapShelf(_ goodreadsShelf: String?) -> Shelf {
        guard let shelf = goodreadsShelf?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return .wantToRead
        }

        switch shelf {
        case "to-read":
            return .wantToRead
        case "currently-reading":
            return .reading
        case "read":
            return .read
        default:
            return .wantToRead
        }
    }

    // MARK: - Private Helpers

    /// Goodreads wraps ISBNs in ="..." notation. Clean that up.
    private static func cleanISBN(_ raw: String?) -> String? {
        guard var isbn = raw else { return nil }
        // Remove ="..." wrapper
        isbn = isbn.replacingOccurrences(of: "=", with: "")
        isbn = isbn.replacingOccurrences(of: "\"", with: "")
        isbn = isbn.trimmingCharacters(in: .whitespaces)
        return isbn.isEmpty ? nil : isbn
    }

    private static func parseDate(_ string: String?, primary: DateFormatter, alt: DateFormatter) -> Date? {
        guard let string else { return nil }
        return primary.date(from: string) ?? alt.date(from: string)
    }
}

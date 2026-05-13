import Foundation

@MainActor
struct DataExporter {

    // MARK: - CSV Export

    static func exportCSV(books: [Book]) -> Data {
        var lines: [String] = []

        // Header row
        lines.append(csvRow([
            "Title", "Author", "ISBN13", "Shelf", "Rating",
            "Date Added", "Date Started", "Date Finished",
            "Current Page", "Notes", "Tags"
        ]))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for book in books {
            let fields: [String] = [
                book.title,
                book.authorName,
                book.isbn13 ?? "",
                book.shelf.displayName,
                book.userRating.map { String(format: "%.1f", $0) } ?? "",
                dateFormatter.string(from: book.dateAdded),
                book.dateStarted.map { dateFormatter.string(from: $0) } ?? "",
                book.dateFinished.map { dateFormatter.string(from: $0) } ?? "",
                book.currentPage.map { String($0) } ?? "",
                book.notes ?? "",
                book.tags.joined(separator: "; ")
            ]
            lines.append(csvRow(fields))
        }

        let csvString = lines.joined(separator: "\n")
        return Data(csvString.utf8)
    }

    // MARK: - JSON Export

    static func exportJSON(books: [Book]) -> Data {
        let dateFormatter = ISO8601DateFormatter()

        let booksArray: [[String: Any]] = books.map { book in
            var dict: [String: Any] = [
                "title": book.title,
                "author": book.authorName,
                "shelf": book.shelf.rawValue,
                "dateAdded": dateFormatter.string(from: book.dateAdded),
                "isFavourite": book.isFavourite,
                "subjects": book.subjects,
                "tags": book.tags
            ]

            if let isbn13 = book.isbn13 { dict["isbn13"] = isbn13 }
            if let isbn10 = book.isbn10 { dict["isbn10"] = isbn10 }
            if let rating = book.userRating { dict["rating"] = rating }
            if let pageCount = book.pageCount { dict["pageCount"] = pageCount }
            if let currentPage = book.currentPage { dict["currentPage"] = currentPage }
            if let dateStarted = book.dateStarted { dict["dateStarted"] = dateFormatter.string(from: dateStarted) }
            if let dateFinished = book.dateFinished { dict["dateFinished"] = dateFormatter.string(from: dateFinished) }
            if let notes = book.notes { dict["notes"] = notes }
            if let synopsis = book.synopsis { dict["synopsis"] = synopsis }
            if let publisher = book.publisher { dict["publisher"] = publisher }
            if let language = book.language { dict["language"] = language }
            if let year = book.firstPublishYear { dict["firstPublishYear"] = year }
            if let coverImageID = book.coverImageID { dict["coverImageID"] = coverImageID }
            if let olEditionKey = book.olEditionKey { dict["olEditionKey"] = olEditionKey }
            if let goodreadsID = book.goodreadsID { dict["goodreadsID"] = goodreadsID }

            dict["olWorkKey"] = book.olWorkKey

            // Read history
            let reads: [[String: Any]] = (book.reads ?? []).map { entry in
                var entryDict: [String: Any] = [:]
                if let start = entry.startDate { entryDict["startDate"] = dateFormatter.string(from: start) }
                if let finish = entry.finishDate { entryDict["finishDate"] = dateFormatter.string(from: finish) }
                if let rating = entry.rating { entryDict["rating"] = rating }
                if let notes = entry.notes { entryDict["notes"] = notes }
                if let dnfPage = entry.dnfPage { entryDict["dnfPage"] = dnfPage }
                if let dnfReason = entry.dnfReason { entryDict["dnfReason"] = dnfReason }
                return entryDict
            }
            if !reads.isEmpty {
                dict["readHistory"] = reads
            }

            return dict
        }

        let export: [String: Any] = [
            "exportDate": dateFormatter.string(from: .now),
            "appVersion": "1.0",
            "bookCount": books.count,
            "books": booksArray
        ]

        guard let data = try? JSONSerialization.data(
            withJSONObject: export,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return Data("{}".utf8)
        }

        return data
    }

    // MARK: - CSV Helpers

    /// Escapes a field for CSV output. Fields containing commas, quotes, or newlines are
    /// wrapped in double quotes, with internal double quotes escaped by doubling.
    private static func escapeCSVField(_ field: String) -> String {
        let needsQuoting = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
        if needsQuoting {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map { escapeCSVField($0) }.joined(separator: ",")
    }
}

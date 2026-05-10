import Foundation

// MARK: - Bookshop Services (#48)

enum BookshopService: String, CaseIterable, Identifiable {
    case bookshopOrg = "Bookshop.org"
    case hive = "Hive"
    case blackwells = "Blackwell's"

    var id: String { rawValue }

    func url(for isbn: String) -> URL? {
        switch self {
        case .bookshopOrg:
            // Affiliate ID placeholder — will be set in App Store Connect
            URL(string: "https://uk.bookshop.org/a/AFFILIATE_ID/\(isbn)")
        case .hive:
            // Hive via Webgains affiliate
            URL(string: "https://www.hive.co.uk/Search?keyword=\(isbn)")
        case .blackwells:
            URL(string: "https://blackwells.co.uk/bookshop/product/\(isbn)")
        }
    }

    var isAffiliate: Bool {
        switch self {
        case .bookshopOrg, .hive: true
        case .blackwells: false
        }
    }
}

enum BookshopPreference: String, CaseIterable {
    case bookshopOrg = "Bookshop.org"
    case hive = "Hive"
    case blackwells = "Blackwell's"
    case all = "Show all"
}

// MARK: - Audiobook Services (#49)

enum AudiobookService: String, CaseIterable, Identifiable {
    case libroFm = "Libro.fm"
    case audibleUK = "Audible UK"

    var id: String { rawValue }

    func url(for isbn: String) -> URL? {
        switch self {
        case .libroFm:
            URL(string: "https://libro.fm/audiobooks/\(isbn)")
        case .audibleUK:
            URL(string: "https://www.audible.co.uk/search?keywords=\(isbn)")
        }
    }
}

enum AudiobookPreference: String, CaseIterable {
    case libroFm = "Libro.fm"
    case audibleUK = "Audible UK"
    case both = "Both"
}

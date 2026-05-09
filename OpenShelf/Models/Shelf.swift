import Foundation

enum Shelf: String, Codable, CaseIterable, Sendable {
    case wantToRead
    case reading
    case read
    case dnf

    var displayName: String {
        switch self {
        case .wantToRead: "Want to Read"
        case .reading: "Reading"
        case .read: "Read"
        case .dnf: "Did Not Finish"
        }
    }

    var systemImage: String {
        switch self {
        case .wantToRead: "bookmark"
        case .reading: "book.fill"
        case .read: "checkmark.circle.fill"
        case .dnf: "xmark.circle"
        }
    }
}

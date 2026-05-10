import AppIntents

enum ShelfAppEnum: String, AppEnum {
    case wantToRead
    case reading
    case read
    case dnf

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Shelf")

    static let caseDisplayRepresentations: [ShelfAppEnum: DisplayRepresentation] = [
        .wantToRead: "Want to Read",
        .reading: "Reading",
        .read: "Read",
        .dnf: "Did Not Finish"
    ]

    var shelf: Shelf {
        switch self {
        case .wantToRead: .wantToRead
        case .reading: .reading
        case .read: .read
        case .dnf: .dnf
        }
    }
}

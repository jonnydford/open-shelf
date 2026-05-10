import Foundation

struct SharedBookEntry: Codable, Sendable {
    let olWorkKey: String
    let title: String
    let authorName: String
    let isbn13: String?
    let coverImageID: Int?
    let rating: Double?
    let note: String?
}

struct SharedListRecord: Identifiable, Sendable {
    let id: String // CKRecord.ID.recordName
    let name: String
    let books: [SharedBookEntry]
    let ownerName: String?
    let lastUpdated: Date
}

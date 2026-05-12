import Foundation

struct ITunesLookupResponse: Codable, Sendable {
    let resultCount: Int
    let results: [ITunesEbook]
}

struct ITunesEbook: Codable, Sendable {
    let trackViewUrl: URL
    let formattedPrice: String?
    let price: Double?
    let currency: String?
}

import Foundation

struct AuthorDetail: Codable, Sendable {
    let key: String
    let name: String?
    let bio: DescriptionValue?
    let birthDate: String?
    let deathDate: String?
    let photos: [Int]?
    let links: [AuthorLink]?
    let remoteIds: RemoteIds?

    var biographyText: String? { bio?.text }
    var primaryPhotoID: Int? { photos?.first }

    struct AuthorLink: Codable, Sendable {
        let title: String?
        let url: String?
    }

    struct RemoteIds: Codable, Sendable {
        let wikidata: String?
        let goodreads: String?
        let storygraph: String?
        let imdb: String?

        enum CodingKeys: String, CodingKey {
            case wikidata, goodreads, storygraph, imdb
        }
    }

    enum CodingKeys: String, CodingKey {
        case key, name, bio, photos, links
        case birthDate = "birth_date"
        case deathDate = "death_date"
        case remoteIds = "remote_ids"
    }
}

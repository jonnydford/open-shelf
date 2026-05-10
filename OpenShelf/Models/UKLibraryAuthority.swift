import Foundation

struct UKLibraryAuthority: Codable, Identifiable, Sendable {
    let name: String
    let region: String
    let system: String
    let slug: String?
    let domain: String?

    var id: String { name }

    var libraryService: LibraryService {
        switch system {
        case "spydus_cloud": .spydusCloud
        case "koha": .koha
        default: .custom
        }
    }
}

struct UKLibraryAuthoritiesPayload: Codable, Sendable {
    let authorities: [UKLibraryAuthority]
}

enum UKLibraryAuthorityLoader {
    static func load() -> [UKLibraryAuthority] {
        guard let url = Bundle.main.url(forResource: "UKLibraryAuthorities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(UKLibraryAuthoritiesPayload.self, from: data)
        else {
            return []
        }
        return payload.authorities
    }

    static var regions: [String] {
        let allRegions = load().map(\.region)
        var seen = Set<String>()
        return allRegions.filter { seen.insert($0).inserted }
    }
}

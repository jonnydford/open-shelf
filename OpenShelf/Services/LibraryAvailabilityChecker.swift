import Foundation

@MainActor
final class LibraryAvailabilityChecker: Sendable {
    static let shared = LibraryAvailabilityChecker()

    private let cache = NSCache<NSString, NSNumber>()

    private init() {
        cache.countLimit = 200
    }

    enum AvailabilityStatus {
        case unknown
        case checking
        case likelyAvailable
        case notFound
    }

    func cachedStatus(for isbn: String) -> AvailabilityStatus {
        guard let cached = cache.object(forKey: isbn as NSString) else {
            return .unknown
        }
        return cached.boolValue ? .likelyAvailable : .notFound
    }

    func check(isbn: String, slug: String) async -> AvailabilityStatus {
        if let cached = cache.object(forKey: isbn as NSString) {
            return cached.boolValue ? .likelyAvailable : .notFound
        }

        guard let url = LibraryService.spydusCloudURL(slug: slug, isbn: isbn) else {
            return .unknown
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .unknown
            }

            guard let html = String(data: data, encoding: .utf8) else {
                return .unknown
            }

            let hasResults = html.contains("resultCount") ||
                html.contains("search-results") ||
                html.contains("item-list") ||
                html.contains("record-detail") ||
                (html.contains("results") && !html.contains("0 results") && !html.contains("No results"))

            let status: AvailabilityStatus = hasResults ? .likelyAvailable : .notFound
            cache.setObject(NSNumber(value: hasResults), forKey: isbn as NSString)
            return status
        } catch {
            // Fail silently
            return .unknown
        }
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}

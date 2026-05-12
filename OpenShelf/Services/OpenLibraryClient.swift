import Foundation
import os

enum CoverSize: String, Sendable {
    case small = "S"
    case medium = "M"
    case large = "L"
}

enum OpenLibraryError: Error, LocalizedError, Sendable {
    case invalidURL
    case networkError(Error)
    case httpError(statusCode: Int)
    case rateLimited
    case decodingError(Error)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .httpError(let code):
            return "Server error (HTTP \(code))."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .decodingError:
            return "Unexpected response from Open Library."
        case .notFound:
            return "Book not found. Try a different search."
        }
    }
}

actor OpenLibraryClient {
    private static let logger = Logger(subsystem: "com.forddevinc.OpenShelf", category: "OpenLibrary")

    private let session: URLSession
    private let baseURL = "https://openlibrary.org"
    private let coversBaseURL = "https://covers.openlibrary.org"
    private let searchFields = "key,title,author_name,first_publish_year,number_of_pages_median,cover_i,edition_count,isbn,subject,id_goodreads"

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.httpAdditionalHeaders = [
                "User-Agent": "OpenShelf/1.0 (contact@openshelf.app)"
            ]
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Search

    func search(query: String) async throws -> [SearchResult] {
        guard var components = URLComponents(string: "\(baseURL)/search.json") else {
            throw OpenLibraryError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: searchFields),
            URLQueryItem(name: "limit", value: "20")
        ]

        guard let url = components.url else {
            throw OpenLibraryError.invalidURL
        }

        let response: SearchResponse = try await performRequest(url: url)
        return response.docs
    }

    // MARK: - Author Search

    func searchByAuthor(name: String) async throws -> [SearchResult] {
        guard var components = URLComponents(string: "\(baseURL)/search.json") else {
            throw OpenLibraryError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "author", value: name),
            URLQueryItem(name: "fields", value: searchFields),
            URLQueryItem(name: "limit", value: "10"),
            URLQueryItem(name: "sort", value: "editions")
        ]

        guard let url = components.url else {
            throw OpenLibraryError.invalidURL
        }

        let response: SearchResponse = try await performRequest(url: url)
        return response.docs
    }

    // MARK: - ISBN Lookup

    func lookupISBN(_ isbn: String) async throws -> EditionDetail {
        guard let url = URL(string: "\(baseURL)/isbn/\(isbn).json") else {
            throw OpenLibraryError.invalidURL
        }

        return try await performRequest(url: url)
    }

    // MARK: - Work Detail

    func fetchWorkDetail(key: String) async throws -> WorkDetail {
        // key comes in as "/works/OL..." — use it directly
        let path = key.hasPrefix("/") ? key : "/works/\(key)"
        guard let url = URL(string: "\(baseURL)\(path).json") else {
            throw OpenLibraryError.invalidURL
        }

        return try await performRequest(url: url)
    }

    // MARK: - Author Works

    func fetchAuthorWorks(authorKey: String, limit: Int = 5) async throws -> AuthorWorksResponse {
        let path = authorKey.hasPrefix("/") ? authorKey : "/authors/\(authorKey)"
        guard var components = URLComponents(string: "\(baseURL)\(path)/works.json") else {
            throw OpenLibraryError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components.url else {
            throw OpenLibraryError.invalidURL
        }

        return try await performRequest(url: url)
    }

    // MARK: - Author Detail

    func fetchAuthorDetail(key: String) async throws -> AuthorDetail {
        let path = key.hasPrefix("/") ? key : "/authors/\(key)"
        guard let url = URL(string: "\(baseURL)\(path).json") else {
            throw OpenLibraryError.invalidURL
        }
        return try await performRequest(url: url)
    }

    // MARK: - Subjects

    func fetchSubject(_ slug: String, limit: Int = 20) async throws -> SubjectResponse {
        let sanitised = slug.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        guard var components = URLComponents(string: "\(baseURL)/subjects/\(sanitised).json") else {
            throw OpenLibraryError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components.url else {
            throw OpenLibraryError.invalidURL
        }
        return try await performRequest(url: url)
    }

    // MARK: - Wikipedia Link Resolution

    func resolveWikipediaURL(wikidataID: String) async throws -> URL? {
        guard wikidataID.range(of: #"^Q[0-9]+$"#, options: .regularExpression) != nil else {
            return nil
        }

        guard var components = URLComponents(string: "https://www.wikidata.org/w/api.php") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "action", value: "wbgetentities"),
            URLQueryItem(name: "ids", value: wikidataID),
            URLQueryItem(name: "props", value: "sitelinks"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "sitefilter", value: "enwiki"),
        ]

        guard let url = components.url else { return nil }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            return nil
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let entities = json?["entities"] as? [String: Any]
        let entity = entities?[wikidataID] as? [String: Any]
        let sitelinks = entity?["sitelinks"] as? [String: Any]
        let enwiki = sitelinks?["enwiki"] as? [String: Any]
        let title = enwiki?["title"] as? String

        guard let title else { return nil }
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        return URL(string: "https://en.wikipedia.org/wiki/\(encoded)")
    }

    // MARK: - Cover URL

    func coverURL(id: Int, size: CoverSize) -> URL {
        // https://covers.openlibrary.org/b/id/{id}-{S|M|L}.jpg
        URL(string: "\(coversBaseURL)/b/id/\(id)-\(size.rawValue).jpg")!
    }

    // MARK: - Private

    private func performRequest<T: Decodable & Sendable>(url: URL) async throws -> T {
        let path = url.path()
        Self.logger.debug("Request started: \(path, privacy: .public)")
        let start = ContinuousClock.now

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            let elapsed = ContinuousClock.now - start
            if (error as? URLError)?.code == .timedOut {
                Self.logger.error("Request timed out after \(elapsed, privacy: .public): \(path, privacy: .public)")
            } else {
                Self.logger.error("Request failed after \(elapsed, privacy: .public): \(path, privacy: .public) — \(error.localizedDescription, privacy: .public)")
            }
            throw OpenLibraryError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenLibraryError.networkError(
                URLError(.badServerResponse)
            )
        }

        let elapsed = ContinuousClock.now - start

        switch httpResponse.statusCode {
        case 200:
            Self.logger.debug("Request completed in \(elapsed, privacy: .public): \(path, privacy: .public)")
        case 404:
            Self.logger.warning("Not found (404) after \(elapsed, privacy: .public): \(path, privacy: .public)")
            throw OpenLibraryError.notFound
        case 429:
            Self.logger.warning("Rate limited (429) after \(elapsed, privacy: .public): \(path, privacy: .public)")
            throw OpenLibraryError.rateLimited
        default:
            Self.logger.error("HTTP \(httpResponse.statusCode) after \(elapsed, privacy: .public): \(path, privacy: .public)")
            throw OpenLibraryError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Self.logger.error("Decoding failed for \(path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw OpenLibraryError.decodingError(error)
        }
    }
}

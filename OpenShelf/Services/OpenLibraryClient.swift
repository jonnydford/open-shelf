import Foundation

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
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
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

    // MARK: - Cover URL

    func coverURL(id: Int, size: CoverSize) -> URL {
        // https://covers.openlibrary.org/b/id/{id}-{S|M|L}.jpg
        URL(string: "\(coversBaseURL)/b/id/\(id)-\(size.rawValue).jpg")!
    }

    // MARK: - Private

    private func performRequest<T: Decodable & Sendable>(url: URL) async throws -> T {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw OpenLibraryError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenLibraryError.networkError(
                URLError(.badServerResponse)
            )
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 404:
            throw OpenLibraryError.notFound
        case 429:
            throw OpenLibraryError.rateLimited
        default:
            throw OpenLibraryError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw OpenLibraryError.decodingError(error)
        }
    }
}

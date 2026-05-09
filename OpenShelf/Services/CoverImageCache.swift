import Foundation
import UIKit

actor CoverImageCache {
    private let cacheDirectory: URL
    private let session: URLSession
    private let baseURL = "https://covers.openlibrary.org/b/id"
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    init(session: URLSession? = nil) {
        // Use the App Group container so the widget extension can read cached covers.
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.openshelf.shared"
        )
        let baseDir = groupURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let coverDir = baseDir.appendingPathComponent("Covers", isDirectory: true)
        self.cacheDirectory = coverDir

        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.httpAdditionalHeaders = [
                "User-Agent": "OpenShelf/1.0 (contact@openshelf.app)"
            ]
            self.session = URLSession(configuration: config)
        }

        // Create cache directory inline (init is nonisolated)
        Self.ensureDirectoryExists(at: coverDir)
    }

    // MARK: - Public API

    func image(for coverID: Int, size: CoverSize) async -> UIImage? {
        let filename = Self.filename(coverID: coverID, size: size)
        let fileURL = cacheDirectory.appendingPathComponent(filename)

        // Check disk cache
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            return image
        }

        // Check if already fetching
        if let existingTask = inFlightTasks[filename] {
            return await existingTask.value
        }

        // Fetch from network
        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            return await self.fetchAndCache(coverID: coverID, size: size, fileURL: fileURL)
        }

        inFlightTasks[filename] = task
        let result = await task.value
        inFlightTasks[filename] = nil
        return result
    }

    func prefetch(coverID: Int, size: CoverSize) async {
        let filename = Self.filename(coverID: coverID, size: size)
        let fileURL = cacheDirectory.appendingPathComponent(filename)

        // Skip if already cached
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return
        }

        _ = await image(for: coverID, size: size)
    }

    func cacheSize() -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    func clearCache() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: cacheDirectory)
        Self.ensureDirectoryExists(at: cacheDirectory)
    }

    // MARK: - Private

    private static nonisolated func ensureDirectoryExists(at url: URL) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private static func filename(coverID: Int, size: CoverSize) -> String {
        "\(coverID)_\(size.rawValue).jpg"
    }

    private func fetchAndCache(coverID: Int, size: CoverSize, fileURL: URL) async -> UIImage? {
        let url = URL(string: "\(baseURL)/\(coverID)-\(size.rawValue).jpg")!

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            guard let image = UIImage(data: data) else {
                return nil
            }

            // Write to disk cache
            try? data.write(to: fileURL, options: .atomic)

            return image
        } catch {
            return nil
        }
    }
}

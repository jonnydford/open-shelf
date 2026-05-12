import Foundation

actor MetadataCache {
    private let cacheDirectory: URL
    private let memoryCache = NSCache<NSString, CacheEntry>()
    private var inFlightTasks: [String: Task<Data?, Never>] = [:]

    private static let workTTL: TimeInterval = 24 * 60 * 60
    private static let authorTTL: TimeInterval = 7 * 24 * 60 * 60

    init() {
        let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.forddevinc.OpenShelf.shared"
        )
        let baseDir = groupURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let metaDir = baseDir.appendingPathComponent("Metadata", isDirectory: true)
        self.cacheDirectory = metaDir

        memoryCache.countLimit = 200

        Self.ensureDirectoryExists(at: metaDir)
    }

    // MARK: - Public API

    func get<T: Decodable & Sendable>(_ type: T.Type, for key: String) -> T? {
        let cacheKey = Self.sanitisedKey(key)

        if let entry = memoryCache.object(forKey: cacheKey as NSString),
           !entry.isExpired {
            return try? JSONDecoder().decode(type, from: entry.data)
        }

        let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
        guard let diskData = try? Data(contentsOf: fileURL) else { return nil }

        guard let envelope = try? JSONDecoder().decode(CacheEnvelope.self, from: diskData),
              !envelope.isExpired else {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        let entry = CacheEntry(data: envelope.data, expiresAt: envelope.expiresAt)
        memoryCache.setObject(entry, forKey: cacheKey as NSString)

        return try? JSONDecoder().decode(type, from: envelope.data)
    }

    func set<T: Encodable & Sendable>(_ value: T, for key: String, ttl: TimeInterval) {
        guard let data = try? JSONEncoder().encode(value) else { return }

        let cacheKey = Self.sanitisedKey(key)
        let expiresAt = Date.now.addingTimeInterval(ttl)

        let entry = CacheEntry(data: data, expiresAt: expiresAt)
        memoryCache.setObject(entry, forKey: cacheKey as NSString)

        let envelope = CacheEnvelope(data: data, expiresAt: expiresAt)
        if let diskData = try? JSONEncoder().encode(envelope) {
            let fileURL = cacheDirectory.appendingPathComponent(cacheKey)
            try? diskData.write(to: fileURL, options: .atomic)
        }
    }

    func cachedWork(for key: String, fetch: @escaping @Sendable () async throws -> WorkDetail) async -> WorkDetail? {
        if let cached: WorkDetail = get(WorkDetail.self, for: key) {
            return cached
        }
        return await deduplicatedFetch(key: key, ttl: Self.workTTL, fetch: fetch)
    }

    func cachedAuthor(for key: String, fetch: @escaping @Sendable () async throws -> AuthorDetail) async -> AuthorDetail? {
        if let cached: AuthorDetail = get(AuthorDetail.self, for: key) {
            return cached
        }
        return await deduplicatedFetch(key: key, ttl: Self.authorTTL, fetch: fetch)
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
        memoryCache.removeAllObjects()
        inFlightTasks.values.forEach { $0.cancel() }
        inFlightTasks.removeAll()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: cacheDirectory)
        Self.ensureDirectoryExists(at: cacheDirectory)
    }

    // MARK: - Private

    private func deduplicatedFetch<T: Codable & Sendable>(
        key: String,
        ttl: TimeInterval,
        fetch: @escaping @Sendable () async throws -> T
    ) async -> T? {
        let cacheKey = Self.sanitisedKey(key)

        if let existingTask = inFlightTasks[cacheKey] {
            guard let data = await existingTask.value else { return nil }
            return try? JSONDecoder().decode(T.self, from: data)
        }

        let task = Task<Data?, Never> {
            do {
                let value = try await fetch()
                let data = try JSONEncoder().encode(value)
                return data
            } catch {
                return nil
            }
        }

        inFlightTasks[cacheKey] = task
        let result = await task.value
        inFlightTasks[cacheKey] = nil

        guard let data = result else { return nil }

        if let value = try? JSONDecoder().decode(T.self, from: data) {
            set(value, for: key, ttl: ttl)
            return value
        }
        return nil
    }

    private static nonisolated func ensureDirectoryExists(at url: URL) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private static func sanitisedKey(_ key: String) -> String {
        key.replacingOccurrences(of: "/", with: "_")
    }
}

// MARK: - Cache Storage Types

private final class CacheEntry: NSObject, @unchecked Sendable {
    let data: Data
    let expiresAt: Date

    var isExpired: Bool { Date.now > expiresAt }

    init(data: Data, expiresAt: Date) {
        self.data = data
        self.expiresAt = expiresAt
    }
}

private struct CacheEnvelope: Codable {
    let data: Data
    let expiresAt: Date

    var isExpired: Bool { Date.now > expiresAt }
}

import CloudKit

@MainActor
@Observable
final class CloudSharingService {
    static let containerIdentifier = "iCloud.com.forddevinc.OpenShelf"
    static let zoneName = "SharedLists"

    private let recordType = "SharedReadingList"
    private let publicShelfRecordType = "PublicShelf"

    private(set) var sharedWithMe: [SharedListRecord] = []
    private(set) var isLoading = false
    private(set) var sharedWithMeFetchFailed = false
    private(set) var publicShelfShareURL: URL?

    private var cachedShares: [String: CKShare] = [:]
    private(set) var hiddenListIDs: Set<String> = []

    private static let seenBooksKey = "seenSharedListBooks"
    private static let hiddenListsKey = "hiddenSharedListIDs"

    private var seenBooksCache: [String: Set<String>]?

    private var _container: CKContainer?
    private var container: CKContainer {
        get throws {
            if let c = _container { return c }
            guard Self.isAvailable else {
                throw CloudSharingError.cloudKitUnavailable
            }
            let c = CKContainer(identifier: Self.containerIdentifier)
            _container = c
            return c
        }
    }

    static var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - Zone Setup

    enum CloudSharingError: Error {
        case cloudKitUnavailable
    }

    private func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneName: Self.zoneName)
        _ = try await container.privateCloudDatabase.save(zone)
    }

    // MARK: - Share a List

    func prepareShare(
        list: ReadingList,
        books: [Book],
        includeRatings: Bool,
        includeNotes: Bool
    ) async throws -> (CKRecord, CKShare, CKContainer) {
        let ckContainer = try container
        try await ensureZoneExists()

        let zoneID = CKRecordZone.ID(zoneName: Self.zoneName)
        let recordID: CKRecord.ID

        if let existingName = list.ckRecordName {
            recordID = CKRecord.ID(recordName: existingName, zoneID: zoneID)
        } else {
            recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        }

        let record = CKRecord(recordType: recordType, recordID: recordID)
        populateRecord(
            record,
            list: list,
            books: books,
            includeRatings: includeRatings,
            includeNotes: includeNotes
        )

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = list.name as CKRecordValue
        share.publicPermission = .none

        _ = try await ckContainer.privateCloudDatabase.modifyRecords(
            saving: [record, share], deleting: []
        )

        cachedShares[record.recordID.recordName] = share

        return (record, share, ckContainer)
    }

    func cachedShare(forRecordName recordName: String) -> CKShare? {
        cachedShares[recordName]
    }

    func resolveContainer() throws -> CKContainer {
        try container
    }

    func updateSharedRecord(
        list: ReadingList,
        books: [Book],
        includeRatings: Bool,
        includeNotes: Bool
    ) async throws {
        guard let recordName = list.ckRecordName else { return }

        try await ensureZoneExists()

        let zoneID = CKRecordZone.ID(zoneName: Self.zoneName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)

        let record = try await container.privateCloudDatabase.record(for: recordID)
        populateRecord(
            record,
            list: list,
            books: books,
            includeRatings: includeRatings,
            includeNotes: includeNotes
        )

        if let share = record.share {
            let shareRecord = try await container.privateCloudDatabase.record(for: share.recordID)
            if let ckShare = shareRecord as? CKShare {
                ckShare[CKShare.SystemFieldKey.title] = list.name as CKRecordValue
            }
        }

        _ = try await container.privateCloudDatabase.save(record)
    }

    func stopSharing(recordName: String) async throws {
        let zoneID = CKRecordZone.ID(zoneName: Self.zoneName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)

        let record = try await container.privateCloudDatabase.record(for: recordID)
        var recordsToDelete = [recordID]
        if let shareRef = record.share {
            recordsToDelete.append(shareRef.recordID)
        }
        _ = try await container.privateCloudDatabase.modifyRecords(
            saving: [], deleting: recordsToDelete
        )
        cachedShares.removeValue(forKey: recordName)
    }

    // MARK: - Shared With Me

    func fetchSharedWithMe() async {
        guard Self.isAvailable else { return }
        loadHiddenListIDs()
        isLoading = true
        defer { isLoading = false }

        do {
            let query = CKQuery(
                recordType: recordType,
                predicate: NSPredicate(value: true)
            )
            let (results, _) = try await container.sharedCloudDatabase.records(
                matching: query
            )

            sharedWithMe = results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                return parseRecord(record)
            }.filter { !hiddenListIDs.contains($0.id) }
            sharedWithMeFetchFailed = false
        } catch {
            if sharedWithMe.isEmpty {
                sharedWithMeFetchFailed = true
            }
        }
    }

    func acceptShare(metadata: CKShare.Metadata) async throws {
        let ckContainer = try container
        _ = try await ckContainer.accept(metadata)

        do {
            let record = try await ckContainer.sharedCloudDatabase.record(for: metadata.rootRecordID)
            if record.recordType == publicShelfRecordType {
                if let json = record["snapshotJSON"] as? String,
                   let data = json.data(using: .utf8) {
                    let ownerName = record.recordID.zoneID.ownerName
                    let displayName = record["displayName"] as? String ?? "Friend"
                    NotificationCenter.default.post(
                        name: .publicShelfFollowed,
                        object: nil,
                        userInfo: [
                            "ownerRecordName": ownerName,
                            "displayName": displayName,
                            "snapshotData": data
                        ]
                    )
                }
                return
            }
        } catch {
            // Could not identify record type — fall through to list refresh
        }

        await fetchSharedWithMe()

        let recordName = metadata.rootRecordID.recordName
        if let list = sharedWithMe.first(where: { $0.id == recordName }) {
            markBooksSeen(for: list.id, bookKeys: list.books.map(\.olWorkKey))
        }
    }

    // MARK: - Seen Books Tracking

    private func loadSeenBooksIfNeeded() -> [String: Set<String>] {
        if let cache = seenBooksCache { return cache }
        let dict = UserDefaults.standard.dictionary(forKey: Self.seenBooksKey) as? [String: [String]] ?? [:]
        let cache = dict.mapValues { Set($0) }
        seenBooksCache = cache
        return cache
    }

    private func persistSeenBooks() {
        guard let cache = seenBooksCache else { return }
        let dict = cache.mapValues { Array($0) }
        UserDefaults.standard.set(dict, forKey: Self.seenBooksKey)
    }

    func seenBookKeys(for listID: String) -> Set<String> {
        loadSeenBooksIfNeeded()[listID] ?? []
    }

    func markBooksSeen(for listID: String, bookKeys: [String]) {
        var cache = loadSeenBooksIfNeeded()
        cache[listID] = Set(bookKeys)
        seenBooksCache = cache
        persistSeenBooks()
    }

    func newBookKeys(in list: SharedListRecord) -> Set<String> {
        let seen = seenBookKeys(for: list.id)
        guard !seen.isEmpty else { return [] }
        let current = Set(list.books.map(\.olWorkKey))
        return current.subtracting(seen)
    }

    // MARK: - Unsubscribe

    func hideSharedList(_ listID: String) {
        hiddenListIDs.insert(listID)
        persistHiddenListIDs()
        sharedWithMe.removeAll { $0.id == listID }

        var cache = loadSeenBooksIfNeeded()
        cache.removeValue(forKey: listID)
        seenBooksCache = cache
        persistSeenBooks()
    }

    func unhideSharedList(_ listID: String) {
        hiddenListIDs.remove(listID)
        persistHiddenListIDs()
    }

    private func persistHiddenListIDs() {
        let store = NSUbiquitousKeyValueStore.default
        store.set(Array(hiddenListIDs), forKey: Self.hiddenListsKey)
        store.synchronize()
    }

    private func loadHiddenListIDs() {
        let cloudIDs = NSUbiquitousKeyValueStore.default.array(forKey: Self.hiddenListsKey) as? [String] ?? []
        let localIDs = UserDefaults.standard.stringArray(forKey: Self.hiddenListsKey) ?? []
        hiddenListIDs = Set(cloudIDs).union(localIDs)
        if !localIDs.isEmpty {
            persistHiddenListIDs()
            UserDefaults.standard.removeObject(forKey: Self.hiddenListsKey)
        }
    }

    // MARK: - Helpers

    private func populateRecord(
        _ record: CKRecord,
        list: ReadingList,
        books: [Book],
        includeRatings: Bool,
        includeNotes: Bool
    ) {
        let shareableBooks = books.filter { !$0.isPrivate }
        let entries = shareableBooks.map { book in
            SharedBookEntry(
                olWorkKey: book.olWorkKey,
                title: book.title,
                authorName: book.authorName,
                isbn13: book.isbn13,
                coverImageID: book.coverImageID,
                rating: includeRatings ? book.userRating : nil,
                note: includeNotes ? book.notes.map { String($0.prefix(200)) } : nil
            )
        }

        record["listName"] = list.name as CKRecordValue
        if let data = try? JSONEncoder().encode(entries),
           let json = String(data: data, encoding: .utf8) {
            record["booksJSON"] = json as CKRecordValue
        }
        record["bookCount"] = entries.count as CKRecordValue
        record["lastUpdated"] = Date() as CKRecordValue
    }

    private func parseRecord(_ record: CKRecord) -> SharedListRecord? {
        guard let name = record["listName"] as? String,
              let json = record["booksJSON"] as? String,
              let data = json.data(using: .utf8),
              let books = try? JSONDecoder().decode(
                  [SharedBookEntry].self, from: data
              ) else {
            return nil
        }

        let ownerName = record.creatorUserRecordID?.recordName
        let lastUpdated = record["lastUpdated"] as? Date
            ?? record.modificationDate ?? .now

        return SharedListRecord(
            id: record.recordID.recordName,
            name: name,
            books: books,
            ownerName: ownerName,
            lastUpdated: lastUpdated
        )
    }

    // MARK: - Public Shelf

    private static let publicShelfRecordName = "myPublicShelf"

    func publishPublicShelf(snapshot: PublicShelfSnapshot) async throws -> URL? {
        let ckContainer = try container
        try await ensureZoneExists()

        let zoneID = CKRecordZone.ID(zoneName: Self.zoneName)
        let recordID = CKRecord.ID(
            recordName: Self.publicShelfRecordName,
            zoneID: zoneID
        )

        let record = CKRecord(recordType: publicShelfRecordType, recordID: recordID)
        populatePublicShelfRecord(record, snapshot: snapshot)

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "\(snapshot.displayName)'s Shelf" as CKRecordValue
        share.publicPermission = .readOnly

        _ = try await ckContainer.privateCloudDatabase.modifyRecords(
            saving: [record, share], deleting: []
        )

        cachedShares[Self.publicShelfRecordName] = share
        publicShelfShareURL = share.url
        return share.url
    }

    func updatePublicShelf(snapshot: PublicShelfSnapshot) async throws {
        try await ensureZoneExists()

        let zoneID = CKRecordZone.ID(zoneName: Self.zoneName)
        let recordID = CKRecord.ID(
            recordName: Self.publicShelfRecordName,
            zoneID: zoneID
        )

        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            populatePublicShelfRecord(record, snapshot: snapshot)

            if let shareRef = record.share {
                let shareRecord = try await container.privateCloudDatabase.record(for: shareRef.recordID)
                if let ckShare = shareRecord as? CKShare {
                    ckShare[CKShare.SystemFieldKey.title] = "\(snapshot.displayName)'s Shelf" as CKRecordValue
                    publicShelfShareURL = ckShare.url
                }
            }

            _ = try await container.privateCloudDatabase.save(record)
        } catch let error as CKError where error.code == .unknownItem {
            _ = try await publishPublicShelf(snapshot: snapshot)
        }
    }

    func unpublishPublicShelf() async throws {
        let zoneID = CKRecordZone.ID(zoneName: Self.zoneName)
        let recordID = CKRecord.ID(
            recordName: Self.publicShelfRecordName,
            zoneID: zoneID
        )

        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            var recordsToDelete = [recordID]
            if let shareRef = record.share {
                recordsToDelete.append(shareRef.recordID)
            }
            _ = try await container.privateCloudDatabase.modifyRecords(
                saving: [], deleting: recordsToDelete
            )
        } catch {
            // Record may not exist — that's fine
        }

        cachedShares.removeValue(forKey: Self.publicShelfRecordName)
        publicShelfShareURL = nil
    }

    func fetchPublicShelfURL() async {
        guard Self.isAvailable else { return }

        let zoneID = CKRecordZone.ID(zoneName: Self.zoneName)
        let recordID = CKRecord.ID(
            recordName: Self.publicShelfRecordName,
            zoneID: zoneID
        )

        do {
            let record = try await container.privateCloudDatabase.record(for: recordID)
            if let shareRef = record.share {
                let shareRecord = try await container.privateCloudDatabase.record(for: shareRef.recordID)
                if let ckShare = shareRecord as? CKShare {
                    publicShelfShareURL = ckShare.url
                }
            }
        } catch {
            publicShelfShareURL = nil
        }
    }

    private func populatePublicShelfRecord(
        _ record: CKRecord,
        snapshot: PublicShelfSnapshot
    ) {
        record["displayName"] = snapshot.displayName as CKRecordValue
        record["lastUpdated"] = snapshot.lastUpdated as CKRecordValue

        if let data = try? JSONEncoder().encode(snapshot),
           let json = String(data: data, encoding: .utf8) {
            record["snapshotJSON"] = json as CKRecordValue
        }
    }

    // MARK: - User Identity

    func fetchUserDisplayName() async -> String? {
        guard Self.isAvailable else { return nil }
        do {
            let ckContainer = try container
            let recordID = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKRecord.ID, Error>) in
                ckContainer.fetchUserRecordID { recordID, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let recordID {
                        continuation.resume(returning: recordID)
                    }
                }
            }
            let identity = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKUserIdentity?, Error>) in
                ckContainer.discoverUserIdentity(withUserRecordID: recordID) { identity, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: identity)
                    }
                }
            }
            guard let components = identity?.nameComponents else { return nil }
            let formatted = PersonNameComponentsFormatter().string(from: components)
            return formatted.isEmpty ? nil : formatted
        } catch {
            return nil
        }
    }

    // MARK: - Following

    func fetchAllFollowedShelfSnapshots() async -> [FollowedShelfInfo] {
        guard Self.isAvailable else { return [] }

        do {
            let query = CKQuery(
                recordType: publicShelfRecordType,
                predicate: NSPredicate(value: true)
            )
            let (results, _) = try await container.sharedCloudDatabase.records(
                matching: query
            )

            return results.compactMap { _, result in
                guard let record = try? result.get(),
                      let json = record["snapshotJSON"] as? String,
                      let data = json.data(using: .utf8) else { return nil }

                let ownerName = record.recordID.zoneID.ownerName
                let displayName = record["displayName"] as? String ?? "Friend"

                return FollowedShelfInfo(
                    ownerRecordName: ownerName,
                    displayName: displayName,
                    snapshotData: data
                )
            }
        } catch {
            return []
        }
    }
}

struct FollowedShelfInfo: Sendable {
    let ownerRecordName: String
    let displayName: String
    let snapshotData: Data
}

extension Notification.Name {
    static let publicShelfFollowed = Notification.Name("publicShelfFollowed")
}

import CloudKit

@MainActor
@Observable
final class CloudSharingService {
    static let containerIdentifier = "iCloud.com.forddevinc.OpenShelf"
    static let zoneName = "SharedLists"

    private let recordType = "SharedReadingList"

    private(set) var sharedWithMe: [SharedListRecord] = []
    private(set) var isLoading = false

    private var cachedShares: [String: CKShare] = [:]

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
            }
        } catch {
            sharedWithMe = []
        }
    }

    func acceptShare(metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
        await fetchSharedWithMe()
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
}

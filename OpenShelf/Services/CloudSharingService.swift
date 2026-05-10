import CloudKit

@MainActor
@Observable
final class CloudSharingService {
    private let container = CKContainer(identifier: "iCloud.com.openshelf.app")
    private let zoneName = "SharedLists"
    private let recordType = "SharedReadingList"

    private(set) var sharedWithMe: [SharedListRecord] = []
    private(set) var isLoading = false

    // MARK: - Zone Setup

    private func ensureZoneExists() async throws {
        let zone = CKRecordZone(zoneName: zoneName)
        _ = try await container.privateCloudDatabase.save(zone)
    }

    // MARK: - Share a List

    /// Creates a CKRecord + CKShare for a reading list.
    /// Returns the root record, share, and container for use with UICloudSharingController.
    func prepareShare(
        list: ReadingList,
        books: [Book],
        includeRatings: Bool,
        includeNotes: Bool
    ) async throws -> (CKRecord, CKShare, CKContainer) {
        try await ensureZoneExists()

        let zoneID = CKRecordZone.ID(zoneName: zoneName)
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
        share.publicPermission = .none // Only explicitly invited participants

        _ = try await container.privateCloudDatabase.modifyRecords(
            saving: [record, share], deleting: []
        )

        return (record, share, container)
    }

    /// Updates an existing shared record when the list changes.
    func updateSharedRecord(
        list: ReadingList,
        books: [Book],
        includeRatings: Bool,
        includeNotes: Bool
    ) async throws {
        guard let recordName = list.ckRecordName else { return }

        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)

        let record = try await container.privateCloudDatabase.record(for: recordID)
        populateRecord(
            record,
            list: list,
            books: books,
            includeRatings: includeRatings,
            includeNotes: includeNotes
        )

        _ = try await container.privateCloudDatabase.save(record)
    }

    /// Stops sharing a list by deleting its CKRecord and CKShare.
    func stopSharing(recordName: String) async throws {
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let recordID = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        _ = try await container.privateCloudDatabase.deleteRecord(withID: recordID)
    }

    // MARK: - Shared With Me

    func fetchSharedWithMe() async {
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

    /// Accepts an incoming CloudKit share.
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
                note: includeNotes ? book.notes : nil
            )
        }

        record["listName"] = list.name as CKRecordValue
        if let data = try? JSONEncoder().encode(entries) {
            record["booksJSON"] = String(data: data, encoding: .utf8)! as CKRecordValue
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

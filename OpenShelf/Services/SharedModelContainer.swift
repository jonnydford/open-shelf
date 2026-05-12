import Foundation
import SwiftData

enum SharedModelContainer {
    /// The URL for the shared SwiftData store within the App Group container.
    /// Both the main app and the widget extension use this URL so they share the same database.
    static var storeURL: URL {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.forddevinc.OpenShelf.shared"
        )
        // Fall back to the default application support directory when the App Group
        // container is unavailable (e.g. simulator without entitlements).
        let baseURL = containerURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return baseURL.appendingPathComponent("OpenShelf.store")
    }

    /// Migrates the SwiftData store from the default Application Support location to the
    /// App Group container on first run. This prevents existing users from losing their
    /// library data when updating to the version that introduced App Group storage.
    static func migrateIfNeeded() {
        let fileManager = FileManager.default

        // The old default store location used by SwiftData before we moved to App Group.
        let oldStoreURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("default.store")

        // Only migrate when the old store exists and the new one does not yet.
        guard fileManager.fileExists(atPath: oldStoreURL.path),
              !fileManager.fileExists(atPath: storeURL.path) else { return }

        // Ensure the destination directory exists.
        let storeDir = storeURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: storeDir, withIntermediateDirectories: true)

        // Copy all SQLite-related files (.store, .store-shm, .store-wal).
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: oldStoreURL.path + suffix)
            let dest = URL(fileURLWithPath: storeURL.path + suffix)
            if fileManager.fileExists(atPath: source.path) {
                try? fileManager.copyItem(at: source, to: dest)
            }
        }
    }

    /// Creates a `ModelContainer` configured for the shared App Group store.
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        // Migrate legacy store to the App Group container before opening.
        migrateIfNeeded()

        let schema = Schema([
            Book.self,
            ReadEntry.self,
            UserTag.self,
            ReadingGoal.self,
            ReadingList.self,
            FollowedAuthor.self,
            DismissedBook.self,
            ReadingDay.self,
            FollowedShelf.self,
            ActivityEvent.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )

        backfillReadingDays(in: container)

        return container
    }

    /// One-time migration that creates ReadingDay records from existing book dates.
    @MainActor
    private static func backfillReadingDays(in container: ModelContainer) {
        let hasBackfilled = UserDefaults.standard.bool(forKey: "hasBackfilledReadingDays")
        guard !hasBackfilled else { return }

        let context = container.mainContext
        let calendar = Calendar.current

        let bookDescriptor = FetchDescriptor<Book>()
        guard let books = try? context.fetch(bookDescriptor) else { return }

        for book in books {
            if let dateStarted = book.dateStarted {
                let startOfDay = calendar.startOfDay(for: dateStarted)
                insertReadingDayIfNeeded(date: startOfDay, bookKey: book.olWorkKey, in: context)
            }
            if let dateFinished = book.dateFinished {
                let startOfDay = calendar.startOfDay(for: dateFinished)
                insertReadingDayIfNeeded(date: startOfDay, bookKey: book.olWorkKey, in: context)
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: "hasBackfilledReadingDays")
    }

    @MainActor
    private static func insertReadingDayIfNeeded(date: Date, bookKey: String, in context: ModelContext) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<ReadingDay>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        guard (try? context.fetch(descriptor))?.isEmpty ?? true else { return }
        context.insert(ReadingDay(date: startOfDay, bookKey: bookKey))
    }
}

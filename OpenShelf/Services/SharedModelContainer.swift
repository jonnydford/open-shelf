import Foundation
import SwiftData

enum SharedModelContainer {
    /// The URL for the shared SwiftData store within the App Group container.
    /// Both the main app and the widget extension use this URL so they share the same database.
    static var storeURL: URL {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.openshelf.shared"
        )
        // Fall back to the default application support directory when the App Group
        // container is unavailable (e.g. simulator without entitlements).
        let baseURL = containerURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return baseURL.appendingPathComponent("OpenShelf.store")
    }

    /// Creates a `ModelContainer` configured for the shared App Group store with CloudKit sync.
    @MainActor
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Book.self,
            ReadEntry.self,
            UserTag.self,
            ReadingGoal.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .automatic
        )
        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}

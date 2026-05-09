import Foundation

/// Shared store URL helper for the widget extension.
/// Mirrors the logic in `SharedModelContainer` but avoids importing the main app target.
enum WidgetSharedStore {
    static var storeURL: URL {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.openshelf.shared"
        )
        let baseURL = containerURL ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return baseURL.appendingPathComponent("OpenShelf.store")
    }
}

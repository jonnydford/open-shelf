import Foundation
import SwiftData

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

    private static let schema = Schema([Book.self, ReadEntry.self, UserTag.self, ReadingGoal.self, ReadingList.self, FollowedAuthor.self])

    private static let container: ModelContainer? = {
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        return try? ModelContainer(for: schema, configurations: [configuration])
    }()

    static func makeContext() throws -> ModelContext {
        guard let container else {
            throw CocoaError(.fileNoSuchFile)
        }
        return ModelContext(container)
    }
}

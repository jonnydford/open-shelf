import SwiftUI
import SwiftData

@main
struct OpenShelfApp: App {
    private let modelContainer: ModelContainer
    private let repository: BookRepository

    init() {
        do {
            let container = try SharedModelContainer.makeContainer()
            self.modelContainer = container
            self.repository = BookRepository(
                modelContext: container.mainContext
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repository)
        }
        .modelContainer(modelContainer)
    }
}

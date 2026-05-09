import SwiftUI
import SwiftData

@main
struct OpenShelfApp: App {
    private let modelContainer: ModelContainer
    private let repository: BookRepository

    init() {
        do {
            let schema = Schema([
                Book.self,
                ReadEntry.self,
                UserTag.self,
                ReadingGoal.self
            ])
            let configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
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

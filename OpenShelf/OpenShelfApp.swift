import SwiftUI
import SwiftData

@main
struct OpenShelfApp: App {
    private let modelContainer: ModelContainer
    private let repository: BookRepository

    @Environment(\.scenePhase) private var scenePhase

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

        AuthorCheckService.registerBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repository)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                AuthorCheckService.scheduleBackgroundCheck()
            }
        }
    }
}

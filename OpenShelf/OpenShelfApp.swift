import SwiftUI
import SwiftData
import CloudKit

@main
struct OpenShelfApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let modelContainer: ModelContainer
    private let repository: BookRepository
    private let sharingService = CloudSharingService()
    private let publicShelfUpdater: PublicShelfUpdater

    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let container = try SharedModelContainer.makeContainer()
            self.modelContainer = container
            let repo = BookRepository(
                modelContext: container.mainContext
            )
            self.repository = repo
            self.publicShelfUpdater = PublicShelfUpdater(
                repository: repo,
                sharingService: sharingService
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        AuthorCheckService.registerBackgroundTask()
        AppDelegate.sharingService = sharingService
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repository)
                .environment(sharingService)
                .environment(publicShelfUpdater)
                .task {
                    SpotlightIndexer.indexAllBooks(from: modelContainer.mainContext)
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                AuthorCheckService.scheduleBackgroundCheck()
            }
        }
    }
}

// MARK: - AppDelegate for CloudKit Share Acceptance

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var sharingService: CloudSharingService?

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task {
            try? await Self.sharingService?.acceptShare(
                metadata: cloudKitShareMetadata
            )
        }
    }
}

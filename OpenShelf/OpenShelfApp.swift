import SwiftUI
import SwiftData
import CloudKit
import CoreSpotlight

@main
struct OpenShelfApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let modelContainer: ModelContainer
    private let repository: BookRepository
    private let sharingService = CloudSharingService()

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
        AppDelegate.sharingService = sharingService
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(repository)
                .environment(sharingService)
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                SpotlightIndexer.indexAllBooks(from: modelContainer.mainContext)
                SpotlightIndexer.indexAllLists(from: modelContainer.mainContext)
            case .background:
                AuthorCheckService.scheduleBackgroundCheck()
            default:
                break
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

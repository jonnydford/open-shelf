import SwiftUI
import SwiftData
import CloudKit

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
            if newPhase == .background {
                AuthorCheckService.scheduleBackgroundCheck()
            }
        }
    }
}

// MARK: - AppDelegate for CloudKit Share Acceptance

final class AppDelegate: NSObject, UIApplicationDelegate {
    nonisolated(unsafe) static var sharingService: CloudSharingService?

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        Task { @MainActor in
            try? await Self.sharingService?.acceptShare(
                metadata: cloudKitShareMetadata
            )
        }
    }
}

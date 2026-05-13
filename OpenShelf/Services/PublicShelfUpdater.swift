import Foundation

@MainActor
@Observable
final class PublicShelfUpdater {
    private let repository: BookRepository
    private let sharingService: CloudSharingService
    private var debounceTask: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private var observation: Any?

    init(repository: BookRepository, sharingService: CloudSharingService) {
        self.repository = repository
        self.sharingService = sharingService

        observation = NotificationCenter.default.addObserver(
            forName: .publicShelfNeedsUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleUpdate()
            }
        }
    }

    deinit {
        if let observation {
            NotificationCenter.default.removeObserver(observation)
        }
    }

    private func scheduleUpdate() {
        guard UserDefaults.standard.bool(forKey: "socialEnabled") else { return }

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await performUpdate()
        }
    }

    private func performUpdate() async {
        let displayName = UserDefaults.standard.string(forKey: "socialDisplayName") ?? "Reader"
        let flags = PublicShelfSnapshot.VisibilityFlags(
            currentlyReading: UserDefaults.standard.object(forKey: "shareCurrentlyReading") as? Bool ?? true,
            recentlyFinished: UserDefaults.standard.object(forKey: "shareRecentlyFinished") as? Bool ?? true,
            ratings: UserDefaults.standard.object(forKey: "shareRatings") as? Bool ?? true,
            goalProgress: UserDefaults.standard.object(forKey: "shareGoalProgress") as? Bool ?? true,
            notes: UserDefaults.standard.object(forKey: "shareNotes") as? Bool ?? false,
            progress: UserDefaults.standard.object(forKey: "shareProgress") as? Bool ?? false
        )

        let snapshot = repository.buildPublicShelfSnapshot(
            displayName: displayName.isEmpty ? "Reader" : displayName,
            flags: flags
        )
        try? await sharingService.updatePublicShelf(snapshot: snapshot)
    }
}

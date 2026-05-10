import SwiftUI
import CloudKit

struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let onStoppedSharing: @MainActor () -> Void
    let onSaved: @MainActor () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadOnly]
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UICloudSharingController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onStoppedSharing: onStoppedSharing, onSaved: onSaved)
    }

    @MainActor
    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onStoppedSharing: @MainActor () -> Void
        let onSaved: @MainActor () -> Void

        init(
            onStoppedSharing: @escaping @MainActor () -> Void,
            onSaved: @escaping @MainActor () -> Void
        ) {
            self.onStoppedSharing = onStoppedSharing
            self.onSaved = onSaved
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {}

        func itemTitle(
            for csc: UICloudSharingController
        ) -> String? {
            nil
        }

        func cloudSharingControllerDidStopSharing(
            _ csc: UICloudSharingController
        ) {
            onStoppedSharing()
        }

        func cloudSharingControllerDidSaveShare(
            _ csc: UICloudSharingController
        ) {
            onSaved()
        }
    }
}

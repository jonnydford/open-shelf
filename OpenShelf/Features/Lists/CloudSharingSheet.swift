import SwiftUI
import CloudKit

struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let onStoppedSharing: () -> Void
    let onSaved: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadOnly, .allowReadWrite]
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UICloudSharingController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onStoppedSharing: onStoppedSharing, onSaved: onSaved)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onStoppedSharing: @Sendable () -> Void
        let onSaved: @Sendable () -> Void

        init(
            onStoppedSharing: @escaping @Sendable () -> Void,
            onSaved: @escaping @Sendable () -> Void
        ) {
            self.onStoppedSharing = onStoppedSharing
            self.onSaved = onSaved
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            // Sharing failed — the controller displays its own alert
        }

        func itemTitle(
            for csc: UICloudSharingController
        ) -> String? {
            nil // Uses CKShare.SystemFieldKey.title set during preparation
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

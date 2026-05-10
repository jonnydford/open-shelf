import UIKit
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Entry point for the Open Shelf share extension.
///
/// Presents a compact SwiftUI view that parses shared URLs or text,
/// looks up the book on Open Library, and saves it to the shared
/// SwiftData store via the App Group container.
@MainActor
final class ShareViewController: UIViewController {

    /// Observable holder for the shared text, so the SwiftUI view
    /// can react when async extraction completes.
    private let sharedInput = SharedInput()

    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(
            rootView: ShareExtensionView(
                sharedInput: sharedInput,
                dismissAction: { [weak self] in
                    self?.extensionContext?.completeRequest(returningItems: nil)
                },
                openURLAction: { [weak self] url in
                    self?.openURL(url)
                }
            )
        )

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)

        // Extract shared content asynchronously
        Task {
            let text = await extractSharedContent()
            sharedInput.text = text
        }
    }

    // MARK: - Extract shared content

    private func extractSharedContent() async -> String {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return ""
        }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for attachment in attachments {
                // Try URL first
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await attachment.loadItem(
                        forTypeIdentifier: UTType.url.identifier
                    ) as? URL {
                        return url.absoluteString
                    }
                }

                // Try plain text
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await attachment.loadItem(
                        forTypeIdentifier: UTType.plainText.identifier
                    ) as? String {
                        return text
                    }
                }
            }
        }

        return ""
    }

    // MARK: - Open URL in main app

    private func openURL(_ url: URL) {
        // Share extensions cannot call UIApplication.shared.open directly.
        // Use the responder chain to find the UIApplication and open the URL.
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let application = next as? UIApplication {
                application.open(url)
                break
            }
            responder = next
        }

        // Dismiss the extension after a brief delay to allow the URL to open.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}

/// Observable container for the shared input text.
/// Allows the view controller to asynchronously extract text
/// and have the SwiftUI view react when it arrives.
@MainActor
@Observable
final class SharedInput {
    var text: String?
}

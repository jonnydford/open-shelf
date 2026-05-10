import SwiftUI

struct ShareCardSheet: View {
    let book: Book
    let coverImage: UIImage?

    @AppStorage("preferredShareFormat") private var preferredFormat: String = ShareFormat.story.rawValue
    @State private var selectedFormat: ShareFormat = .story
    @State private var showActivitySheet = false
    @State private var shareItems: [Any] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                // Live preview (scaled down to fit screen)
                ShareCardView(book: book, coverImage: coverImage, format: selectedFormat)
                    .scaleEffect(previewScale)
                    .frame(width: previewWidth, height: previewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    .shadow(radius: 8)

                Spacer()

                ShareFormatPicker(selectedFormat: $selectedFormat)
                    .padding(.horizontal)

                Button {
                    renderAndShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
            }
            .padding(.vertical)
            .navigationTitle("Share Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedFormat = ShareFormat(rawValue: preferredFormat) ?? .story
            }
            .onChange(of: selectedFormat) { _, newValue in
                preferredFormat = newValue.rawValue
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivityView(activityItems: shareItems, applicationActivities: nil)
            }
        }
    }

    // MARK: - Preview Dimensions

    private var previewScale: CGFloat {
        300.0 / selectedFormat.dimensions.width
    }

    private var previewWidth: CGFloat {
        selectedFormat.dimensions.width * previewScale
    }

    private var previewHeight: CGFloat {
        selectedFormat.dimensions.height * previewScale
    }

    // MARK: - Share

    private func renderAndShare() {
        guard !book.isPrivate else { return }
        guard let image = ShareCardRenderer.renderImage(
            for: book,
            coverImage: coverImage,
            format: selectedFormat
        ) else { return }

        var items: [Any] = [image]

        let workKeyPath = book.olWorkKey.replacingOccurrences(of: "/works/", with: "")
        if let encoded = workKeyPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let deepLink = URL(string: "openshelf://book/\(encoded)") {
            items.append(deepLink)
        }

        shareItems = items
        showActivitySheet = true
    }
}

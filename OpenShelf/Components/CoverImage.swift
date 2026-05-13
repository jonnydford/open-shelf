import SwiftUI

struct CoverImage: View {
    let coverID: Int?
    var bookKey: String? = nil
    var size: CoverSize = .medium
    var accessibilityTitle: String? = nil
    @State private var image: UIImage?
    @State private var isLoading = false
    @Environment(BookRepository.self) private var repository

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder
            }
        }
        .accessibilityLabel(accessibilityTitle.map { "Book cover for \($0)" } ?? "Book cover")
        .task(id: coverID) {
            await loadImage()
        }
        .task(id: bookKey) {
            await loadImage()
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(.quaternary)
            Image(systemName: "book.closed")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    private func loadImage() async {
        if let bookKey, let local = repository.imageCache.localCover(for: bookKey) {
            image = local
            return
        }

        guard let coverID else { return }

        isLoading = true
        defer { isLoading = false }

        image = await repository.imageCache.image(for: coverID, size: size)
    }
}

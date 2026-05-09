import SwiftUI

// MARK: - Share Card View (rendered to image via ImageRenderer)

struct ShareCardView: View {
    let book: Book
    let coverImage: UIImage?

    private var cardWidth: CGFloat { 1080 }
    private var cardHeight: CGFloat { 1350 }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)

                coverSection
                    .padding(.bottom, 40)

                titleSection
                    .padding(.bottom, 12)

                authorSection
                    .padding(.bottom, 32)

                statusSection
                    .padding(.bottom, 24)

                quoteSection
                    .padding(.bottom, 32)

                Spacer()

                brandingSection
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 64)
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.15, green: 0.15, blue: 0.25),
                     Color(red: 0.08, green: 0.08, blue: 0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Cover

    private var coverSection: some View {
        Group {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 320, height: 480)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 320, height: 480)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            }
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(book.title)
            .font(.system(size: 40, weight: .bold, design: .serif))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
    }

    // MARK: - Author

    private var authorSection: some View {
        Text("by \(book.authorName)")
            .font(.system(size: 26, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
    }

    // MARK: - Status (varies by shelf)

    @ViewBuilder
    private var statusSection: some View {
        switch book.shelf {
        case .reading:
            currentlyReadingStatus
        case .read:
            finishedStatus
        case .wantToRead:
            wantToReadStatus
        case .dnf:
            dnfStatus
        }
    }

    private var currentlyReadingStatus: some View {
        VStack(spacing: 12) {
            Text("Currently Reading")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))

            if let currentPage = book.currentPage,
               let pageCount = book.pageCount, pageCount > 0 {
                let progress = min(Double(currentPage) / Double(pageCount), 1.0)
                VStack(spacing: 6) {
                    ProgressView(value: progress)
                        .tint(.green)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .frame(width: 400)
                    Text("\(Int(progress * 100))% complete")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private var finishedStatus: some View {
        VStack(spacing: 12) {
            if let rating = book.userRating {
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: starImageName(for: star, rating: rating))
                            .font(.system(size: 28))
                            .foregroundStyle(.yellow)
                    }
                }
            }

            if let dateFinished = book.dateFinished {
                Text("Finished on \(dateFinished.formatted(date: .long, time: .omitted))")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var wantToReadStatus: some View {
        Text("On my reading list")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
    }

    private var dnfStatus: some View {
        Text("Did Not Finish")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.orange.opacity(0.9))
    }

    // MARK: - Quote from notes

    @ViewBuilder
    private var quoteSection: some View {
        if let notes = book.notes, !notes.isEmpty {
            let snippet = String(notes.prefix(100))
            let displayText = notes.count > 100 ? "\(snippet)..." : snippet

            Text("\"\(displayText)\"")
                .font(.system(size: 20, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Branding

    private var brandingSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 18))
            Text("Open Shelf")
                .font(.system(size: 20, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.4))
    }

    // MARK: - Helpers

    private func starImageName(for star: Int, rating: Double) -> String {
        if Double(star) <= rating {
            return "star.fill"
        } else if Double(star) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }
}

// MARK: - Share Card Renderer

@MainActor
enum ShareCardRenderer {
    static func renderImage(for book: Book, coverImage: UIImage?) -> UIImage? {
        let cardView = ShareCardView(book: book, coverImage: coverImage)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 2.0 // High resolution
        return renderer.uiImage
    }
}

// MARK: - Share Sheet Helper (UIActivityViewController bridge)

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

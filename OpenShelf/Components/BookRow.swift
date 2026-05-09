import SwiftUI

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(coverID: book.coverImageID, size: .small)
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(book.authorName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    shelfBadge

                    if let rating = book.userRating, rating > 0 {
                        ratingStars(rating: rating)
                    }
                }

                if book.shelf == .reading, let currentPage = book.currentPage, let pageCount = book.pageCount, pageCount > 0 {
                    progressBar(current: currentPage, total: pageCount)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Shelf Badge

    private var shelfBadge: some View {
        Text(book.shelf.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(shelfColor.opacity(0.15))
            .foregroundStyle(shelfColor)
            .clipShape(Capsule())
    }

    private var shelfColor: Color {
        switch book.shelf {
        case .wantToRead: .blue
        case .reading: .green
        case .read: .gray
        case .dnf: .orange
        }
    }

    // MARK: - Rating Stars

    private func ratingStars(rating: Double) -> some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starImageName(for: star, rating: rating))
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func starImageName(for star: Int, rating: Double) -> String {
        if Double(star) <= rating {
            return "star.fill"
        } else if Double(star) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    // MARK: - Progress Bar

    private func progressBar(current: Int, total: Int) -> some View {
        let progress = min(Double(current) / Double(total), 1.0)
        return VStack(alignment: .leading, spacing: 2) {
            ProgressView(value: progress)
                .tint(.green)
            Text("\(current) of \(total) pages")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

import SwiftUI

struct BookRow: View {
    let book: Book
    var showLockIcon: Bool = false

    @ScaledMetric(relativeTo: .body) private var coverWidth: CGFloat = 60
    @ScaledMetric(relativeTo: .body) private var coverHeight: CGFloat = 90
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                CoverImage(coverID: book.coverImageID, size: .small)
                    .frame(width: coverWidth, height: coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                if let formatBadge = formatAbbreviation {
                    Text(formatBadge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.85))
                        .clipShape(Capsule())
                        .offset(x: 2, y: 2)
                }

                if showLockIcon {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .offset(x: 2, y: 2)
                }
            }
            .accessibilityLabel("Book cover for \(book.title)\(showLockIcon ? ", private" : "")")

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
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = [book.title, "by \(book.authorName)", book.shelf.displayName]
        if let rating = book.userRating, rating > 0 {
            if rating == floor(rating) {
                parts.append("rated \(Int(rating)) out of 5 stars")
            } else {
                parts.append("rated \(String(format: "%.1f", rating)) out of 5 stars")
            }
        }
        if book.shelf == .reading, let currentPage = book.currentPage, let pageCount = book.pageCount, pageCount > 0 {
            let percentage = Int(min(Double(currentPage) / Double(pageCount), 1.0) * 100)
            parts.append("reading progress: \(percentage) percent")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Format Badge

    private var formatAbbreviation: String? {
        switch book.format {
        case .graphicNovel: "GN"
        case .manga: "Manga"
        case .comic: "Comic"
        case .book: nil
        }
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
            .accessibilityLabel("Shelf: \(book.shelf.displayName)")
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

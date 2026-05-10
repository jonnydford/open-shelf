import SwiftUI

struct SharedWithMeView: View {
    @Environment(CloudSharingService.self) private var sharingService

    var body: some View {
        Group {
            if sharingService.isLoading && sharingService.sharedWithMe.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sharingService.sharedWithMe.isEmpty {
                ContentUnavailableView {
                    Label("No Shared Lists", systemImage: "person.2.slash")
                } description: {
                    Text("Lists shared with you via iCloud will appear here.")
                }
            } else {
                List(sharingService.sharedWithMe) { list in
                    NavigationLink {
                        SharedListDetailView(list: list)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(list.name)
                                .font(.headline)
                            HStack(spacing: 8) {
                                Text(
                                    "\(list.books.count) "
                                    + "\(list.books.count == 1 ? "book" : "books")"
                                )
                                Text(list.lastUpdated, style: .relative)
                                    + Text(" ago")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await sharingService.fetchSharedWithMe()
                }
            }
        }
        .navigationTitle("Shared with Me")
        .task {
            await sharingService.fetchSharedWithMe()
        }
    }
}

struct SharedListDetailView: View {
    let list: SharedListRecord

    var body: some View {
        List(list.books, id: \.olWorkKey) { book in
            HStack(spacing: 12) {
                if let coverID = book.coverImageID {
                    AsyncImage(
                        url: URL(
                            string: "https://covers.openlibrary.org/b/id/\(coverID)-M.jpg"
                        )
                    ) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 44, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 66)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(book.authorName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let rating = book.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                            Text(
                                rating == floor(rating)
                                    ? String(format: "%.0f", rating)
                                    : String(format: "%.1f", rating)
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let note = book.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
        .navigationTitle(list.name)
    }
}

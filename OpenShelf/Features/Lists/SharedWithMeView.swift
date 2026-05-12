import SwiftUI

struct SharedWithMeView: View {
    @Environment(CloudSharingService.self) private var sharingService

    @State private var listToUnsubscribe: SharedListRecord?

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
                        SharedListDetailView(listID: list.id)
                    } label: {
                        sharedListRow(list)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            listToUnsubscribe = list
                        } label: {
                            Label("Unsubscribe", systemImage: "xmark.circle")
                        }
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
        .alert("Unsubscribe?", isPresented: Binding(
            get: { listToUnsubscribe != nil },
            set: { if !$0 { listToUnsubscribe = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Unsubscribe", role: .destructive) {
                if let list = listToUnsubscribe {
                    sharingService.hideSharedList(list.id)
                }
            }
        } message: {
            if let list = listToUnsubscribe {
                Text("You'll no longer see updates to \"\(list.name)\". You'll need the owner to share it again to re-subscribe.")
            }
        }
    }

    private func sharedListRow(_ list: SharedListRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name)
                    .font(.headline)
                HStack(spacing: 8) {
                    Text(
                        "\(list.books.count) "
                        + "\(list.books.count == 1 ? "book" : "books")"
                    )
                    Text("\(list.lastUpdated, style: .relative) ago")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Spacer()

            let newCount = sharingService.newBookKeys(in: list).count
            if newCount > 0 {
                Text("\(newCount) new")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
            }
        }
    }
}

struct SharedListDetailView: View {
    let listID: String

    @Environment(CloudSharingService.self) private var sharingService

    private var list: SharedListRecord? {
        sharingService.sharedWithMe.first { $0.id == listID }
    }

    var body: some View {
        if let list {
            let newKeys = sharingService.newBookKeys(in: list)

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
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xSmall))
                    } else {
                        Image(systemName: "book.closed.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 66)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(book.title)
                                .font(.headline)
                                .lineLimit(2)
                            if newKeys.contains(book.olWorkKey) {
                                Text("New")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Color.accentColor, in: Capsule())
                            }
                        }
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
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await sharingService.fetchSharedWithMe()
            }
            .toolbar {
                ToolbarItem(placement: .status) {
                    Text("Updated \(list.lastUpdated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .onDisappear {
                sharingService.markBooksSeen(
                    for: listID,
                    bookKeys: list.books.map(\.olWorkKey)
                )
            }
        } else {
            ContentUnavailableView {
                Label("List Not Found", systemImage: "tray")
            } description: {
                Text("This list may have been removed.")
            }
        }
    }
}

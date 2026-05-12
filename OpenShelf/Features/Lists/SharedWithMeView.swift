import SwiftUI
import SwiftData

struct SharedWithMeView: View {
    @Environment(CloudSharingService.self) private var sharingService

    @State private var listToUnsubscribe: SharedListRecord?

    var body: some View {
        let newCounts = sharingService.sharedWithMe.reduce(into: [String: Int]()) { dict, list in
            dict[list.id] = sharingService.newBookKeys(in: list).count
        }

        Group {
            if sharingService.isLoading && sharingService.sharedWithMe.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sharingService.sharedWithMeFetchFailed && sharingService.sharedWithMe.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "icloud.slash")
                } description: {
                    Text("Something went wrong. Check your connection or iCloud settings and try again.")
                } actions: {
                    Button("Retry") {
                        Task { await sharingService.fetchSharedWithMe() }
                    }
                }
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
                        sharedListRow(list, newCount: newCounts[list.id] ?? 0)
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
                Text("You'll no longer see updates to \"\(list.name)\".")
            }
        }
    }

    private func sharedListRow(_ list: SharedListRecord, newCount: Int) -> some View {
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

            if newCount > 0 {
                Text("\(newCount) new")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
                    .accessibilityLabel("\(newCount) new \(newCount == 1 ? "book" : "books")")
            }
        }
    }
}

struct SharedListDetailView: View {
    let listID: String

    @Environment(CloudSharingService.self) private var sharingService
    @Environment(\.modelContext) private var modelContext
    @Query private var libraryBooks: [Book]

    @State private var newKeys: Set<String> = []
    @State private var showAddedToast = false

    private var list: SharedListRecord? {
        sharingService.sharedWithMe.first { $0.id == listID }
    }

    var body: some View {
        if let list {
            List(list.books, id: \.olWorkKey) { book in
                NavigationLink {
                    SearchResultDetailView(searchResult: book.asSearchResult)
                } label: {
                    sharedBookRow(book)
                }
                .contextMenu {
                    if isInLibrary(book) {
                        Label("Already in Library", systemImage: "checkmark.circle")
                    } else {
                        Button {
                            addToShelf(book)
                        } label: {
                            Label("Add to Want to Read", systemImage: "bookmark")
                        }
                    }
                }
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
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toast(isPresented: $showAddedToast, message: "Added to Want to Read")
            .task {
                newKeys = sharingService.newBookKeys(in: list)
            }
            .onDisappear {
                if let current = self.list {
                    sharingService.markBooksSeen(
                        for: listID,
                        bookKeys: current.books.map(\.olWorkKey)
                    )
                }
            }
        } else {
            ContentUnavailableView {
                Label("List Not Found", systemImage: "tray")
            } description: {
                Text("This list may have been removed.")
            }
        }
    }

    private func sharedBookRow(_ book: SharedBookEntry) -> some View {
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
                            .accessibilityLabel("New addition")
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

    private func isInLibrary(_ book: SharedBookEntry) -> Bool {
        libraryBooks.contains { $0.olWorkKey == book.olWorkKey }
    }

    private func addToShelf(_ book: SharedBookEntry) {
        let newBook = Book(
            olWorkKey: book.olWorkKey,
            isbn13: book.isbn13,
            title: book.title,
            authorName: book.authorName,
            coverImageID: book.coverImageID,
            shelf: .wantToRead
        )
        modelContext.insert(newBook)
        do {
            try modelContext.save()
            showAddedToast = true
        } catch {
            modelContext.rollback()
        }
    }
}

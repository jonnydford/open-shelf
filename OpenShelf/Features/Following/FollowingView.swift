import SwiftUI
import SwiftData

struct FollowingView: View {
    @Query(sort: \FollowedShelf.displayName) private var followedShelves: [FollowedShelf]
    @Query(sort: \ActivityEvent.timestamp, order: .reverse) private var activityEvents: [ActivityEvent]
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSharingService.self) private var sharingService

    @State private var shelfToUnfollow: FollowedShelf?
    @State private var showClearAllAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if followedShelves.isEmpty && activityEvents.isEmpty {
                    ContentUnavailableView {
                        Label("No Friends Yet", systemImage: "person.2")
                    } description: {
                        Text("When a friend shares their shelf link with you, tap it to follow their reading activity.\n\nShare your own shelf from Settings to let friends follow you too.")
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Following")
            .refreshable {
                await refreshAll()
            }
            .task {
                pruneExpiredEvents()
                let hasStale = followedShelves.contains(where: \.isStale)
                if hasStale {
                    await refreshAll()
                }
            }
            .alert("Unfollow?", isPresented: Binding(
                get: { shelfToUnfollow != nil },
                set: { if !$0 { shelfToUnfollow = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Unfollow", role: .destructive) {
                    if let shelf = shelfToUnfollow {
                        modelContext.delete(shelf)
                        try? modelContext.save()
                    }
                }
            } message: {
                if let shelf = shelfToUnfollow {
                    Text("You'll need \(shelf.displayName) to share their link again to re-follow.")
                }
            }
            .alert("Clear Activity?", isPresented: $showClearAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    clearAllEvents()
                }
            } message: {
                Text("This will remove all activity events from your feed.")
            }
        }
    }

    private var list: some View {
        List {
            if !activityEvents.isEmpty {
                Section {
                    ForEach(activityEvents) { event in
                        if let searchResult = event.asSearchResult {
                            NavigationLink {
                                SearchResultDetailView(searchResult: searchResult)
                            } label: {
                                ActivityEventRow(event: event)
                            }
                        } else {
                            ActivityEventRow(event: event)
                        }
                    }
                } header: {
                    HStack {
                        Text("Activity")
                        Spacer()
                        Button("Clear All") {
                            showClearAllAlert = true
                        }
                        .font(.caption)
                        .textCase(nil)
                    }
                }
            }

            Section("Friends") {
                ForEach(followedShelves) { shelf in
                    NavigationLink {
                        FriendShelfDetailView(shelf: shelf)
                    } label: {
                        FriendShelfRow(shelf: shelf)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            shelfToUnfollow = shelf
                        } label: {
                            Label("Unfollow", systemImage: "person.badge.minus")
                        }
                    }
                }
            }
        }
    }

    private func refreshAll() async {
        let snapshots = await sharingService.fetchAllFollowedShelfSnapshots()

        for info in snapshots {
            if let existing = followedShelves.first(where: { $0.ownerRecordName == info.ownerRecordName }) {
                let oldSnapshot = existing.decodedSnapshot
                let newSnapshot = try? JSONDecoder().decode(PublicShelfSnapshot.self, from: info.snapshotData)

                if let newSnapshot {
                    let events = ActivityDiffEngine.diff(
                        old: oldSnapshot,
                        new: newSnapshot,
                        friendDisplayName: info.displayName,
                        friendRecordName: info.ownerRecordName
                    )
                    for event in events {
                        modelContext.insert(event)
                    }
                }

                existing.displayName = info.displayName
                existing.cachedSnapshot = info.snapshotData
                existing.lastFetched = .now
            } else {
                let shelf = FollowedShelf(
                    ownerRecordName: info.ownerRecordName,
                    displayName: info.displayName,
                    cachedSnapshot: info.snapshotData
                )
                modelContext.insert(shelf)
            }
        }
        try? modelContext.save()
    }

    private func clearAllEvents() {
        for event in activityEvents {
            modelContext.delete(event)
        }
        try? modelContext.save()
    }

    private func pruneExpiredEvents() {
        let expired = activityEvents.filter(\.isExpired)
        for event in expired {
            modelContext.delete(event)
        }
        if !expired.isEmpty {
            try? modelContext.save()
        }
    }
}

// MARK: - Friend Shelf Row

struct FriendShelfRow: View {
    let shelf: FollowedShelf

    var body: some View {
        HStack(spacing: 12) {
            initialsAvatar

            VStack(alignment: .leading, spacing: 2) {
                Text(shelf.displayName)
                    .font(.headline)

                if let snapshot = shelf.decodedSnapshot {
                    let count = snapshot.currentlyReading.count
                    if count > 0 {
                        Text("Reading \(count) book\(count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if !snapshot.recentlyFinished.isEmpty {
                        let finished = snapshot.recentlyFinished.count
                        Text("Recently finished \(finished) book\(finished == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(shelf.lastFetched, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var initialsAvatar: some View {
        let initial = shelf.displayName.first.map(String.init) ?? "?"
        return Circle()
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: 44, height: 44)
            .overlay {
                Text(initial)
                    .font(.title3.bold())
                    .foregroundStyle(Color.accentColor)
            }
    }
}

// MARK: - Friend Shelf Detail

struct FriendShelfDetailView: View {
    let shelf: FollowedShelf

    @Query private var libraryBooks: [Book]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddedToast = false

    private var hasActivity: Bool {
        guard let snapshot = shelf.decodedSnapshot else { return false }
        return !snapshot.currentlyReading.isEmpty
            || !snapshot.recentlyFinished.isEmpty
            || snapshot.goalProgress != nil
    }

    private func isInLibrary(_ book: PublicBookEntry) -> Bool {
        libraryBooks.contains { $0.olWorkKey == book.olWorkKey }
    }

    var body: some View {
        if let snapshot = shelf.decodedSnapshot, hasActivity {
            List {
                if !snapshot.currentlyReading.isEmpty {
                    Section("Currently Reading") {
                        ForEach(snapshot.currentlyReading) { book in
                            publicBookRow(book)
                        }
                    }
                }

                if !snapshot.recentlyFinished.isEmpty {
                    Section("Recently Finished") {
                        ForEach(snapshot.recentlyFinished) { book in
                            publicBookRow(book)
                        }
                    }
                }

                if let goal = snapshot.goalProgress {
                    Section("Reading Goal") {
                        Text(goal)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("\(snapshot.displayName)'s Shelf")
            .navigationBarTitleDisplayMode(.inline)
            .toast(isPresented: $showAddedToast, message: "Added to Want to Read")
        } else if shelf.decodedSnapshot != nil {
            ContentUnavailableView {
                Label("No Recent Activity", systemImage: "book.closed")
            } description: {
                Text("\(shelf.displayName) hasn't shared any reading activity yet.")
            }
            .navigationTitle(shelf.displayName)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView {
                Label("No Data", systemImage: "tray")
            } description: {
                Text("Pull to refresh to load this shelf.")
            }
            .navigationTitle(shelf.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func publicBookRow(_ book: PublicBookEntry) -> some View {
        HStack(spacing: 12) {
            CoverImage(coverID: book.coverImageID, size: .small)
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Text(book.authorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let rating = book.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                if let note = book.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
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

    private func addToShelf(_ book: PublicBookEntry) {
        let newBook = Book(
            olWorkKey: book.olWorkKey,
            isbn13: book.isbn13,
            title: book.title,
            authorName: book.authorName,
            coverImageID: book.coverImageID,
            shelf: .wantToRead
        )
        modelContext.insert(newBook)
        try? modelContext.save()
        showAddedToast = true
    }
}

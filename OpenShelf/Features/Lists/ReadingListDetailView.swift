import SwiftUI
import SwiftData
import CloudKit

struct ReadingListDetailView: View {
    @Bindable var readingList: ReadingList

    @Environment(\.modelContext) private var modelContext
    @Environment(BookRepository.self) private var repository
    @Environment(CloudSharingService.self) private var sharingService
    @Query(sort: \Book.title) private var allBooks: [Book]

    @State private var showAddBooks = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var shareAsImage = false
    @State private var shareImage: UIImage?
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showCloudSharing = false
    @State private var activeShare: CKShare?
    @State private var activeContainer: CKContainer?
    @State private var isSharingInProgress = false
    @State private var sharingError: String?

    private var booksInList: [Book] {
        allBooks.filter { readingList.bookKeys.contains($0.olWorkKey) }
    }

    var body: some View {
        Group {
            if booksInList.isEmpty {
                emptyState
            } else {
                booksList
            }
        }
        .navigationTitle(readingList.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showAddBooks = true
                    } label: {
                        Label("Add Books", systemImage: "plus")
                    }

                    Divider()

                    shareMenu

                    Divider()

                    Button {
                        renameText = readingList.name
                        showRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Toggle(isOn: $readingList.includeRatings) {
                        Label("Include Ratings", systemImage: "star")
                    }

                    Toggle(isOn: $readingList.includeNotes) {
                        Label("Include Notes", systemImage: "note.text")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("List options")
            }
        }
        .sheet(isPresented: $showAddBooks) {
            addBooksSheet
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: shareItems, applicationActivities: nil)
        }
        .alert("Rename List", isPresented: $showRenameAlert) {
            TextField("List name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    readingList.name = trimmed
                    try? modelContext.save()
                    updateSharedRecordIfNeeded()
                }
            }
        }
        .alert(
            "Sharing Failed",
            isPresented: Binding(
                get: { sharingError != nil },
                set: { if !$0 { sharingError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = sharingError {
                Text(error)
            }
        }
        .onChange(of: readingList.includeRatings) {
            try? modelContext.save()
            updateSharedRecordIfNeeded()
        }
        .onChange(of: readingList.includeNotes) {
            try? modelContext.save()
            updateSharedRecordIfNeeded()
        }
        .sheet(isPresented: $showCloudSharing) {
            if let share = activeShare, let ckContainer = activeContainer {
                CloudSharingSheet(
                    share: share,
                    container: ckContainer,
                    onStoppedSharing: {
                        readingList.ckRecordName = nil
                        try? modelContext.save()
                    },
                    onSaved: {
                        showCloudSharing = false
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Books", systemImage: "book.closed")
        } description: {
            Text("Add books from your library to this list.")
        } actions: {
            Button("Add Books") {
                showAddBooks = true
            }
        }
    }

    // MARK: - Books List

    private var booksList: some View {
        List {
            ForEach(booksInList) { book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    BookRow(book: book)
                }
                .accessibilityAction(named: "Remove from list") {
                    readingList.bookKeys.removeAll { $0 == book.olWorkKey }
                    try? modelContext.save()
                }
            }
            .onDelete(perform: removeBooks)
        }
        .listStyle(.plain)
    }

    // MARK: - Share Menu

    @ViewBuilder
    private var shareMenu: some View {
        Button {
            shareAsText()
        } label: {
            Label("Share as Text", systemImage: "doc.plaintext")
        }

        Button {
            shareAsCardImage()
        } label: {
            Label("Share as Image", systemImage: "photo")
        }

        Divider()

        if CloudSharingService.isAvailable {
            if readingList.ckRecordName != nil {
                Button {
                    Task { await manageExistingShare() }
                } label: {
                    Label("Manage iCloud Sharing", systemImage: "person.2.circle")
                }

                Button {
                    Task { await stopSharing() }
                } label: {
                    Label("Stop Sharing", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    Task { await startSharing() }
                } label: {
                    Label("Share via iCloud", systemImage: "icloud.and.arrow.up")
                }
                .disabled(isSharingInProgress)
            }
        }
    }

    // MARK: - Add Books Sheet

    private var addBooksSheet: some View {
        NavigationStack {
            AddBooksToListView(readingList: readingList, allBooks: allBooks)
                .navigationTitle("Add Books")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showAddBooks = false
                        }
                    }
                }
        }
    }

    // MARK: - Actions

    private func removeBooks(at offsets: IndexSet) {
        let booksToRemove = offsets.map { booksInList[$0] }
        for book in booksToRemove {
            readingList.bookKeys.removeAll { $0 == book.olWorkKey }
        }
        try? modelContext.save()
        let currentBooks = booksInList
        if readingList.ckRecordName != nil {
            Task {
                try? await sharingService.updateSharedRecord(
                    list: readingList,
                    books: currentBooks,
                    includeRatings: readingList.includeRatings,
                    includeNotes: readingList.includeNotes
                )
            }
        }
    }

    private func shareAsText() {
        var text = "\u{1F4DA} \(readingList.name)\n\n"

        let shareableBooks = booksInList.filter { !$0.isPrivate }
        for (index, book) in shareableBooks.enumerated() {
            var line = "\(index + 1). \(book.title) by \(book.authorName)"

            if readingList.includeRatings, let rating = book.userRating {
                let ratingText: String
                if rating == floor(rating) {
                    ratingText = String(format: "%.0f", rating)
                } else {
                    ratingText = String(format: "%.1f", rating)
                }
                line += " \u{2B50} \(ratingText)/5"
            }

            text += line + "\n"

            if readingList.includeNotes, let notes = book.notes, !notes.isEmpty {
                let snippet = String(notes.prefix(100))
                text += "   \(snippet)\n"
            }
        }

        text += "\nShared from Open Shelf"

        shareItems = [text]
        showShareSheet = true
    }

    private func shareAsCardImage() {
        let shareableBooks = booksInList.filter { !$0.isPrivate }
        let cardView = ReadingListCardView(
            listName: readingList.name,
            books: shareableBooks,
            includeRatings: readingList.includeRatings
        )
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 2.0

        if let image = renderer.uiImage {
            shareItems = [image]
            showShareSheet = true
        }
    }

    // MARK: - iCloud Sharing

    private func startSharing() async {
        isSharingInProgress = true
        defer { isSharingInProgress = false }
        do {
            let (record, share, ckContainer) = try await sharingService.prepareShare(
                list: readingList,
                books: booksInList,
                includeRatings: readingList.includeRatings,
                includeNotes: readingList.includeNotes
            )
            readingList.ckRecordName = record.recordID.recordName
            try? modelContext.save()
            activeShare = share
            activeContainer = ckContainer
            showCloudSharing = true
        } catch {
            sharingError = "Could not share this list. Make sure you're signed into iCloud."
        }
    }

    private func manageExistingShare() async {
        guard let recordName = readingList.ckRecordName else { return }
        if let cached = sharingService.cachedShare(forRecordName: recordName) {
            activeShare = cached
            showCloudSharing = true
            return
        }
        sharingError = "Could not load sharing details. Try stopping and re-sharing this list."
    }

    private func stopSharing() async {
        guard let recordName = readingList.ckRecordName else { return }
        do {
            try await sharingService.stopSharing(recordName: recordName)
        } catch {
            // Best-effort cleanup
        }
        readingList.ckRecordName = nil
        try? modelContext.save()
    }

    private func updateSharedRecordIfNeeded() {
        guard readingList.ckRecordName != nil else { return }
        let currentBooks = booksInList
        Task {
            try? await sharingService.updateSharedRecord(
                list: readingList,
                books: currentBooks,
                includeRatings: readingList.includeRatings,
                includeNotes: readingList.includeNotes
            )
        }
    }
}

// MARK: - Add Books to List View

struct AddBooksToListView: View {
    @Bindable var readingList: ReadingList
    let allBooks: [Book]

    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSharingService.self) private var sharingService
    @State private var searchText = ""

    private var filteredBooks: [Book] {
        if searchText.isEmpty {
            return allBooks
        }
        let query = searchText.lowercased()
        return allBooks.filter {
            $0.title.lowercased().contains(query) ||
            $0.authorName.lowercased().contains(query)
        }
    }

    var body: some View {
        List {
            ForEach(filteredBooks) { book in
                Button {
                    toggleBook(book)
                } label: {
                    HStack {
                        BookRow(book: book)
                        Spacer()
                        if readingList.bookKeys.contains(book.olWorkKey) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
            }
        }
        .listStyle(.plain)
        .searchable(text: $searchText, prompt: "Filter books")
    }

    private func toggleBook(_ book: Book) {
        if readingList.bookKeys.contains(book.olWorkKey) {
            readingList.bookKeys.removeAll { $0 == book.olWorkKey }
        } else {
            readingList.bookKeys.append(book.olWorkKey)
        }
        try? modelContext.save()
        if readingList.ckRecordName != nil {
            let updatedBooks = allBooks.filter {
                readingList.bookKeys.contains($0.olWorkKey)
            }
            Task {
                try? await sharingService.updateSharedRecord(
                    list: readingList,
                    books: updatedBooks,
                    includeRatings: readingList.includeRatings,
                    includeNotes: readingList.includeNotes
                )
            }
        }
    }
}

// MARK: - Reading List Card View (rendered to image)

struct ReadingListCardView: View {
    let listName: String
    let books: [Book]
    let includeRatings: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.8))

                Text(listName)
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("\(books.count) \(books.count == 1 ? "book" : "books")")
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 60)
            .padding(.bottom, 32)

            // Book list
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(books.prefix(10).enumerated()), id: \.element.olWorkKey) { index, book in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 32, alignment: .trailing)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Text(book.authorName)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .lineLimit(1)

                                if includeRatings, let rating = book.userRating {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                        let ratingText: String = rating == floor(rating)
                                            ? String(format: "%.0f", rating)
                                            : String(format: "%.1f", rating)
                                        Text(ratingText)
                                            .font(.system(size: 14))
                                    }
                                    .foregroundStyle(.yellow.opacity(0.8))
                                }
                            }
                        }
                    }
                }

                if books.count > 10 {
                    Text("+ \(books.count - 10) more")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.leading, 44)
                }
            }
            .padding(.horizontal, 48)

            Spacer()

            // Branding
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 16))
                Text("Open Shelf")
                    .font(.system(size: 18, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.3))
            .padding(.bottom, 48)
        }
        .frame(width: 1080, height: 1350)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.18, blue: 0.28),
                         Color(red: 0.06, green: 0.10, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

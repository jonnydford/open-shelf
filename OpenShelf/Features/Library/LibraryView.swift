import SwiftUI
import SwiftData

// MARK: - Sort Option

enum LibrarySortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case titleAZ = "Title A\u{2013}Z"
    case authorAZ = "Author A\u{2013}Z"
    case rating = "Rating"
    case dateFinished = "Date Finished"
}

// MARK: - Shelf Filter (includes "All")

enum ShelfFilter: Hashable, CaseIterable {
    case all
    case shelf(Shelf)

    static var allCases: [ShelfFilter] {
        [.all] + Shelf.allCases.map { .shelf($0) }
    }

    var displayName: String {
        switch self {
        case .all: "All"
        case .shelf(let shelf): shelf.displayName
        }
    }

    var shortName: String {
        switch self {
        case .all: "All"
        case .shelf(.wantToRead): "Want"
        case .shelf(.reading): "Reading"
        case .shelf(.read): "Read"
        case .shelf(.dnf): "DNF"
        }
    }
}

// MARK: - Library View

struct LibraryView: View {
    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var allBooks: [Book]

    @State private var selectedFilter: ShelfFilter = .all
    @State private var sortOption: LibrarySortOption = .dateAdded
    @State private var localSearchText = ""

    // Shelf management states
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bookToDelete: Book?
    @State private var showDeleteConfirmation = false
    @State private var bookForRating: Book?
    @State private var showRatingPrompt = false
    @State private var pendingRating: Double?
    @State private var bookForDNF: Book?
    @State private var showDNFPrompt = false
    @State private var dnfPage: String = ""
    @State private var dnfReason: String = ""

    // Add-book flow states
    @State private var showBarcodeScanner = false
    @State private var showManualEntry = false

    private var filteredBooks: [Book] {
        var books = allBooks

        // Filter by shelf
        switch selectedFilter {
        case .all:
            break
        case .shelf(let shelf):
            books = books.filter { $0.shelf == shelf }
        }

        // Filter by local search
        if !localSearchText.isEmpty {
            let query = localSearchText.lowercased()
            books = books.filter {
                $0.title.lowercased().contains(query) ||
                $0.authorName.lowercased().contains(query)
            }
        }

        // Sort
        switch sortOption {
        case .dateAdded:
            books.sort { $0.dateAdded > $1.dateAdded }
        case .titleAZ:
            books.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .authorAZ:
            books.sort { $0.authorName.localizedCaseInsensitiveCompare($1.authorName) == .orderedAscending }
        case .rating:
            books.sort { ($0.userRating ?? 0) > ($1.userRating ?? 0) }
        case .dateFinished:
            books.sort { ($0.dateFinished ?? .distantPast) > ($1.dateFinished ?? .distantPast) }
        }

        return books
    }

    @State private var pendingNewBooks: [PendingNewBook] = AuthorCheckService.pendingNewBooks

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                newBookBanner
                shelfPicker

                Group {
                    if filteredBooks.isEmpty {
                        emptyState
                    } else {
                        bookList
                    }
                }
            }
            .navigationTitle("Library")
            .onAppear {
                pendingNewBooks = AuthorCheckService.pendingNewBooks
            }
            .searchable(text: $localSearchText, prompt: "Filter by title or author")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addButton
                }
                ToolbarItem(placement: .secondaryAction) {
                    readingListsButton
                }
                ToolbarItem(placement: .secondaryAction) {
                    sortMenu
                }
            }
            .alert("Delete Book", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    bookToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let book = bookToDelete {
                        repository.deleteBook(book)
                        bookToDelete = nil
                    }
                }
            } message: {
                if let book = bookToDelete {
                    Text("Are you sure you want to remove \"\(book.title)\" from your library? This cannot be undone.")
                }
            }
            .sheet(isPresented: $showRatingPrompt) {
                ratingSheet
            }
            .sheet(isPresented: $showDNFPrompt) {
                dnfSheet
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView()
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView()
            }
        }
    }

    // MARK: - New Book Banner

    @ViewBuilder
    private var newBookBanner: some View {
        ForEach(pendingNewBooks) { pending in
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("New book by \(pending.authorName)")
                        .font(.subheadline.bold())
                    Text(pending.bookTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    AuthorCheckService.dismissPendingBook(workKey: pending.workKey)
                    pendingNewBooks = AuthorCheckService.pendingNewBooks
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.08))
        }
    }

    // MARK: - Shelf Picker

    private var shelfPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShelfFilter.allCases, id: \.self) { filter in
                    Button {
                        if reduceMotion {
                            selectedFilter = filter
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedFilter = filter
                            }
                        }
                    } label: {
                        Text(filter.shortName)
                            .font(.subheadline)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedFilter == filter ? Color.accentColor : Color.clear
                            )
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selectedFilter == filter ? Color.clear : Color.secondary.opacity(0.3),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Filter: \(filter.displayName)")
                    .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shelf filter")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label(emptyStateTitle, systemImage: emptyStateIcon)
        } description: {
            Text(emptyStateMessage)
        } actions: {
            if !localSearchText.isEmpty {
                Button("Clear Search") {
                    localSearchText = ""
                }
            } else {
                NavigationLink {
                    SearchView()
                } label: {
                    Text("Add your first book")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateTitle: String {
        if !localSearchText.isEmpty {
            return "No Matches"
        }
        switch selectedFilter {
        case .all: return "No Books Yet"
        case .shelf(.wantToRead): return "Nothing on Your Wishlist"
        case .shelf(.reading): return "Not Reading Anything"
        case .shelf(.read): return "No Books Finished"
        case .shelf(.dnf): return "No Abandoned Books"
        }
    }

    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: "books.vertical"
        case .shelf(.wantToRead): "bookmark"
        case .shelf(.reading): "book.fill"
        case .shelf(.read): "checkmark.circle"
        case .shelf(.dnf): "xmark.circle"
        }
    }

    private var emptyStateMessage: String {
        if !localSearchText.isEmpty {
            return "No books match '\(localSearchText)'."
        }
        switch selectedFilter {
        case .all: return "Search for books to add to your library."
        case .shelf(.wantToRead): return "Books you want to read will appear here."
        case .shelf(.reading): return "Books you are currently reading will appear here."
        case .shelf(.read): return "Books you have finished will appear here."
        case .shelf(.dnf): return "Books you did not finish will appear here."
        }
    }

    // MARK: - Up Next Queue

    private var queuedBooks: [Book] {
        filteredBooks
            .filter { $0.queuePosition != nil }
            .sorted { $0.queuePosition! < $1.queuePosition! }
    }

    private var nonQueuedBooks: [Book] {
        filteredBooks.filter { $0.queuePosition == nil }
    }

    private var isWantToReadShelf: Bool {
        if case .shelf(.wantToRead) = selectedFilter { return true }
        return false
    }

    // MARK: - Book List

    private var bookList: some View {
        List {
            if isWantToReadShelf && !queuedBooks.isEmpty {
                upNextSection
            }

            regularBooksSection
        }
        .listStyle(.plain)
        .refreshable {
            // No-op for local data — satisfies pull-to-refresh UX expectation
        }
    }

    private var upNextSection: some View {
        Section {
            ForEach(queuedBooks) { book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    HStack {
                        BookRow(book: book)
                        if book.queuePosition == 0 {
                            Spacer()
                            Text("Reading Next")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        bookToDelete = book
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        repository.removeFromQueue(book)
                    } label: {
                        Label("Remove from Up Next", systemImage: "minus.circle")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    contextMenuItems(for: book)
                }
            }
            .onMove { source, destination in
                var reordered = queuedBooks
                reordered.move(fromOffsets: source, toOffset: destination)
                repository.reorderQueue(reordered)
            }
        } header: {
            Label("Up Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private var regularBooksSection: some View {
        Section {
            let books = isWantToReadShelf ? nonQueuedBooks : filteredBooks
            ForEach(books) { book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    BookRow(book: book)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        bookToDelete = book
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    shelfSwipeActions(for: book)
                }
                .contextMenu {
                    contextMenuItems(for: book)
                }
            }
        }
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private func shelfSwipeActions(for book: Book) -> some View {
        ForEach(Shelf.allCases.filter { $0 != book.shelf }, id: \.self) { shelf in
            Button {
                moveBook(book, to: shelf)
            } label: {
                Label(shelf.displayName, systemImage: shelf.systemImage)
            }
            .tint(shelfTint(shelf))
        }
    }

    private func shelfTint(_ shelf: Shelf) -> Color {
        switch shelf {
        case .wantToRead: .blue
        case .reading: .green
        case .read: .gray
        case .dnf: .orange
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for book: Book) -> some View {
        Menu("Move to Shelf") {
            ForEach(Shelf.allCases, id: \.self) { shelf in
                Button {
                    moveBook(book, to: shelf)
                } label: {
                    if book.shelf == shelf {
                        Label(shelf.displayName, systemImage: "checkmark")
                    } else {
                        Label(shelf.displayName, systemImage: shelf.systemImage)
                    }
                }
                .disabled(book.shelf == shelf)
            }
        }

        // Up Next queue actions
        if book.shelf == .wantToRead {
            if book.queuePosition != nil {
                Button {
                    repository.removeFromQueue(book)
                } label: {
                    Label("Remove from Up Next", systemImage: "minus.circle")
                }
            } else {
                Button {
                    repository.addToQueue(book)
                } label: {
                    Label("Add to Up Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
            }
        }

        Button {
            book.isFavourite.toggle()
            try? modelContext.save()
        } label: {
            Label(
                book.isFavourite ? "Unfavourite" : "Favourite",
                systemImage: book.isFavourite ? "heart.slash" : "heart"
            )
        }

        Divider()

        Button(role: .destructive) {
            bookToDelete = book
            showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Toolbar Items

    private var addButton: some View {
        Menu {
            NavigationLink {
                SearchView()
            } label: {
                Label("Search Open Library", systemImage: "magnifyingglass")
            }

            #if !targetEnvironment(simulator)
            Button {
                showBarcodeScanner = true
            } label: {
                Label("Scan Barcode", systemImage: "barcode.viewfinder")
            }
            #endif

            Button {
                showManualEntry = true
            } label: {
                Label("Add Manually", systemImage: "square.and.pencil")
            }
        } label: {
            Image(systemName: "plus")
        }
    }

    private var readingListsButton: some View {
        NavigationLink {
            ReadingListsView()
        } label: {
            Image(systemName: "list.bullet.rectangle")
        }
        .accessibilityLabel("Reading lists")
    }

    private var sortMenu: some View {
        Menu {
            ForEach(LibrarySortOption.allCases, id: \.self) { option in
                Button {
                    sortOption = option
                } label: {
                    if sortOption == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    // MARK: - Rating Sheet

    private var ratingSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("Rate This Book")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Would you like to rate this book?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                RatingPicker(rating: $pendingRating, mode: .interactive)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        finalizeShelfMove(bookForRating, to: .read, rating: nil)
                        bookForRating = nil
                        showRatingPrompt = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Rating") {
                        finalizeShelfMove(bookForRating, to: .read, rating: pendingRating)
                        bookForRating = nil
                        showRatingPrompt = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - DNF Sheet

    private var dnfSheet: some View {
        NavigationStack {
            Form {
                Section("Page stopped at (optional)") {
                    TextField("Page number", text: $dnfPage)
                        .keyboardType(.numberPad)
                }
                Section("Reason (optional)") {
                    TextField("Why did you stop?", text: $dnfReason, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Did Not Finish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDNFPrompt = false
                        bookForDNF = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let book = bookForDNF {
                            let entry = ReadEntry(
                                book: book,
                                startDate: book.dateStarted,
                                finishDate: .now,
                                dnfPage: Int(dnfPage),
                                dnfReason: dnfReason.isEmpty ? nil : dnfReason
                            )
                            modelContext.insert(entry)
                            repository.updateShelf(book, to: .dnf)
                            try? modelContext.save()
                        }
                        showDNFPrompt = false
                        bookForDNF = nil
                        dnfPage = ""
                        dnfReason = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Shelf Move Logic

    private func moveBook(_ book: Book, to shelf: Shelf) {
        switch shelf {
        case .read:
            bookForRating = book
            pendingRating = nil
            showRatingPrompt = true
        case .dnf:
            bookForDNF = book
            dnfPage = ""
            dnfReason = ""
            showDNFPrompt = true
        default:
            repository.updateShelf(book, to: shelf)
        }
    }

    private func finalizeShelfMove(_ book: Book?, to shelf: Shelf, rating: Double?) {
        guard let book else { return }

        // Create ReadEntry when marking as read
        if shelf == .read {
            let entry = ReadEntry(
                book: book,
                startDate: book.dateStarted,
                finishDate: .now,
                rating: rating
            )
            modelContext.insert(entry)
        }

        repository.updateShelf(book, to: shelf)
        if let rating {
            repository.updateRating(book, rating: rating)
        }
    }
}

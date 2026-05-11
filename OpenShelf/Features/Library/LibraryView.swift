import SwiftUI
import SwiftData
import LocalAuthentication

extension Notification.Name {
    static let searchOpenLibrary = Notification.Name("searchOpenLibrary")
}

// MARK: - Sort Option

enum LibrarySortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case titleAZ = "Title A\u{2013}Z"
    case authorAZ = "Author A\u{2013}Z"
    case rating = "Rating"
    case dateFinished = "Date Finished"
    case series = "Series"
}

// MARK: - Shelf Filter (includes "All")

enum ShelfFilter: Hashable, CaseIterable {
    case all
    case shelf(Shelf)
    case favourites

    static var allCases: [ShelfFilter] {
        [.all] + Shelf.allCases.map { .shelf($0) } + [.favourites]
    }

    var displayName: String {
        switch self {
        case .all: "All"
        case .shelf(let shelf): shelf.displayName
        case .favourites: "Favourites"
        }
    }

    var shortName: String {
        switch self {
        case .all: "All"
        case .shelf(.wantToRead): "Want"
        case .shelf(.reading): "Reading"
        case .shelf(.read): "Read"
        case .shelf(.dnf): "DNF"
        case .favourites: "Favourites"
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
    @State private var showPrivateBooks: Bool = false
    @State private var formatFilter: BookFormat? = nil

    // Shelf management states
    @Environment(\.scenePhase) private var scenePhase
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

        // Filter out private books unless authenticated
        if !showPrivateBooks {
            books = books.filter { !$0.isPrivate }
        }

        // Filter by shelf
        switch selectedFilter {
        case .all:
            break
        case .shelf(let shelf):
            books = books.filter { $0.shelf == shelf }
        case .favourites:
            books = books.filter { $0.isFavourite }
        }

        // Filter by format
        if let formatFilter {
            books = books.filter { $0.format == formatFilter }
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
        case .series:
            books.sort { lhs, rhs in
                // Books with seriesName come first, sorted by series then position
                switch (lhs.seriesName, rhs.seriesName) {
                case (nil, nil):
                    return lhs.dateAdded > rhs.dateAdded
                case (nil, _):
                    return false
                case (_, nil):
                    return true
                case let (lhsSeries?, rhsSeries?):
                    let cmp = lhsSeries.localizedCaseInsensitiveCompare(rhsSeries)
                    if cmp == .orderedSame {
                        return (lhs.seriesPosition ?? Int.max) < (rhs.seriesPosition ?? Int.max)
                    }
                    return cmp == .orderedAscending
                }
            }
        }

        return books
    }

    @State private var pendingNewBooks: [PendingNewBook] = AuthorCheckService.pendingNewBooks

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WorldBookDayBanner(books: allBooks)
                newBookBanner
                shelfPicker
                sortAndFilterBar

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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    showPrivateBooks = false
                }
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
                ToolbarItem(placement: .secondaryAction) {
                    privateToggleButton
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
                    .foregroundStyle(Color.accentColor)

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
            .background(.quaternary)
        }
    }

    // MARK: - Shelf Picker

    private var favouritesCount: Int {
        var books = allBooks
        if !showPrivateBooks {
            books = books.filter { !$0.isPrivate }
        }
        return books.filter { $0.isFavourite }.count
    }

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
                        HStack(spacing: 4) {
                            if filter == .favourites {
                                Image(systemName: "heart.fill")
                                    .font(.caption)
                            }
                            if filter == .favourites {
                                Text("\(filter.shortName) (\(favouritesCount))")
                            } else {
                                Text(filter.shortName)
                            }
                        }
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

    // MARK: - Sort & Filter Bar

    private var sortDisplayLabel: String {
        switch sortOption {
        case .dateAdded: "Date Added \u{2193}"
        case .titleAZ: "Title A\u{2013}Z"
        case .authorAZ: "Author A\u{2013}Z"
        case .rating: "Rating \u{2193}"
        case .dateFinished: "Date Finished \u{2193}"
        case .series: "Series"
        }
    }

    private var sortAndFilterBar: some View {
        HStack(spacing: 8) {
            Menu {
                Section("Sort By") {
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
                }
            } label: {
                Text("Sorted by: \(sortDisplayLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sort order: \(sortDisplayLabel). Tap to change.")

            if let format = formatFilter {
                Button {
                    formatFilter = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text(format.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Format filter: \(format.rawValue). Tap to clear.")
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView {
                Label(emptyStateTitle, systemImage: emptyStateIcon)
            } description: {
                Text(emptyStateMessage)
            } actions: {
                if !localSearchText.isEmpty {
                    Button("Clear Search") {
                        localSearchText = ""
                    }
                } else if selectedFilter != .favourites {
                    NavigationLink {
                        SearchView()
                    } label: {
                        Text("Add your first book")
                    }
                }
            }

            if !localSearchText.isEmpty {
                VStack(spacing: 8) {
                    Text("Not in your library")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Button {
                        NotificationCenter.default.post(
                            name: .searchOpenLibrary,
                            object: nil,
                            userInfo: ["query": localSearchText]
                        )
                    } label: {
                        Label("Search Open Library?", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
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
        case .favourites: return "No Favourites Yet"
        }
    }

    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: "books.vertical"
        case .shelf(.wantToRead): "bookmark"
        case .shelf(.reading): "book.fill"
        case .shelf(.read): "checkmark.circle"
        case .shelf(.dnf): "xmark.circle"
        case .favourites: "heart"
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
        case .favourites: return "No favourites yet. Long-press a book to add one."
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
            ForEach(Array(queuedBooks.enumerated()), id: \.element.id) { _, book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    HStack {
                        BookRow(book: book, showLockIcon: showPrivateBooks && book.isPrivate)
                        if book.queuePosition == 0 {
                            Spacer()
                            Text("Reading Next")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
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
                .accessibilityAction(named: "Remove from Up Next") {
                    repository.removeFromQueue(book)
                }
                .accessibilityAction(named: "Delete") {
                    bookToDelete = book
                    showDeleteConfirmation = true
                }
            }
        } header: {
            Label("Up Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private var regularBooksSection: some View {
        let books = isWantToReadShelf ? nonQueuedBooks : filteredBooks

        if sortOption == .series {
            seriesGroupedSections(books: books)
        } else {
            Section {
                ForEach(books) { book in
                    bookNavigationRow(book)
                }
            }
        }
    }

    @ViewBuilder
    private func seriesGroupedSections(books: [Book]) -> some View {
        let withSeries = books.filter { $0.seriesName != nil }
        let withoutSeries = books.filter { $0.seriesName == nil }

        let seriesGroups: [(name: String, books: [Book])] = {
            var groups: [String: [Book]] = [:]
            for book in withSeries {
                let name = book.seriesName ?? ""
                groups[name, default: []].append(book)
            }
            return groups.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .map { (name: $0, books: groups[$0]!) }
        }()

        ForEach(seriesGroups, id: \.name) { group in
            Section {
                ForEach(group.books) { book in
                    bookNavigationRow(book)
                }
            } header: {
                let readCount = group.books.filter { $0.shelf == .read }.count
                let totalCount = group.books.count
                Label("\(group.name) — \(readCount) of \(totalCount) read", systemImage: "books.vertical")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }

        if !withoutSeries.isEmpty {
            Section {
                ForEach(withoutSeries) { book in
                    bookNavigationRow(book)
                }
            } header: {
                Text("Standalone")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }

    private func bookNavigationRow(_ book: Book) -> some View {
        NavigationLink {
            BookDetailView(book: book)
        } label: {
            BookRow(book: book, showLockIcon: showPrivateBooks && book.isPrivate)
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
        .accessibilityAction(named: "Delete") {
            bookToDelete = book
            showDeleteConfirmation = true
        }
        .accessibilityAction(named: "Move to Want to Read") {
            moveBook(book, to: .wantToRead)
        }
        .accessibilityAction(named: "Move to Reading") {
            moveBook(book, to: .reading)
        }
        .accessibilityAction(named: "Move to Read") {
            moveBook(book, to: .read)
        }
        .accessibilityAction(named: "Move to Did Not Finish") {
            moveBook(book, to: .dnf)
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
        .accessibilityLabel("Add book")
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
            Section("Sort By") {
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
            }

            Section("Format") {
                Button {
                    formatFilter = nil
                } label: {
                    if formatFilter == nil {
                        Label("All Formats", systemImage: "checkmark")
                    } else {
                        Text("All Formats")
                    }
                }

                ForEach(BookFormat.allCases, id: \.self) { format in
                    Button {
                        formatFilter = format
                    } label: {
                        if formatFilter == format {
                            Label(format.rawValue, systemImage: "checkmark")
                        } else {
                            Text(format.rawValue)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel("Sort and filter")
    }

    private var privateToggleButton: some View {
        Button {
            if showPrivateBooks {
                showPrivateBooks = false
            } else {
                authenticateForPrivateBooks()
            }
        } label: {
            Label(
                showPrivateBooks ? "Hide Private Books" : "Show Private Books",
                systemImage: showPrivateBooks ? "lock.open" : "lock"
            )
        }
    }

    private func authenticateForPrivateBooks() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Show private books"
            ) { success, _ in
                Task { @MainActor in
                    if success {
                        showPrivateBooks = true
                    }
                }
            }
        } else {
            // No biometrics or passcode — show directly
            showPrivateBooks = true
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

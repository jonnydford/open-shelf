import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The main SwiftUI view for the share extension.
///
/// Displays a compact card that parses the shared URL/text, looks up the
/// book on Open Library, and lets the user save it to their library.
struct ShareExtensionView: View {
    let sharedInput: SharedInput
    let dismissAction: @MainActor () -> Void
    let openURLAction: @MainActor (URL) -> Void

    @State private var state: ShareState = .loading
    @State private var selectedShelf: Shelf = .wantToRead
    @State private var parsedIdentifier: ParsedBookIdentifier?
    @State private var existingBook: Book?
    @State private var isSaving = false

    private let client = OpenLibraryClient()
    private let modelContainer: ModelContainer? = {
        let schema = Schema([
            Book.self,
            ReadEntry.self,
            UserTag.self,
            ReadingGoal.self,
            ReadingList.self,
            FollowedAuthor.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            url: SharedModelContainer.storeURL,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()

            // Content
            Group {
                switch state {
                case .loading:
                    loadingView
                case .found(let info):
                    bookFoundView(info)
                case .alreadyInLibrary(let info):
                    alreadyInLibraryView(info)
                case .notFound:
                    notFoundView
                case .error(let message):
                    errorView(message)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: sharedInput.text) { _, newValue in
            if let text = newValue {
                Task {
                    await loadContent(from: text)
                }
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button("Cancel") {
                dismissAction()
            }
            .font(.body)

            Spacer()

            Text("Add to Open Shelf")
                .font(.headline)

            Spacer()

            // Invisible spacer to balance the Cancel button
            Text("Cancel")
                .font(.body)
                .hidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Looking up book...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Book Found

    private func bookFoundView(_ info: BookInfo) -> some View {
        VStack(spacing: 16) {
            bookCard(info)

            shelfPicker

            addButton(info)
        }
        .padding()
    }

    // MARK: - Already in Library

    private func alreadyInLibraryView(_ info: BookInfo) -> some View {
        VStack(spacing: 16) {
            bookCard(info)

            if let book = existingBook {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Already in your library")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("(\(book.shelf.displayName))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            shelfPicker

            Button {
                updateExistingBook()
            } label: {
                Text("Update Shelf")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(existingBook?.shelf == selectedShelf)
        }
        .padding()
    }

    // MARK: - Not Found

    private var notFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Book Not Found")
                .font(.headline)

            Text("We couldn't find a match for this link.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                openInMainApp()
            } label: {
                Label("Open in Open Shelf", systemImage: "arrow.up.forward.app")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                openInMainApp()
            } label: {
                Label("Open in Open Shelf", systemImage: "arrow.up.forward.app")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Shared Components

    private func bookCard(_ info: BookInfo) -> some View {
        HStack(spacing: 12) {
            // Cover thumbnail
            if let coverID = info.coverID {
                AsyncImage(url: coverURL(id: coverID)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))
                        .overlay {
                            Image(systemName: "book.closed")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 60, height: 90)
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(info.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(info.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let year = info.firstPublishYear {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var shelfPicker: some View {
        Picker("Shelf", selection: $selectedShelf) {
            Text("Want to Read").tag(Shelf.wantToRead)
            Text("Currently Reading").tag(Shelf.reading)
            Text("Read").tag(Shelf.read)
        }
        .pickerStyle(.segmented)
    }

    private func addButton(_ info: BookInfo) -> some View {
        Button {
            Task {
                await saveBook(info)
            }
        } label: {
            if isSaving {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                Text("Add to Library")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isSaving)
    }

    // MARK: - Cover URL

    private func coverURL(id: Int) -> URL {
        URL(string: "https://covers.openlibrary.org/b/id/\(id)-M.jpg")!
    }

    // MARK: - Load Content

    @MainActor
    private func loadContent(from input: String) async {
        guard !input.isEmpty else {
            state = .notFound
            return
        }

        let identifier = BookURLParser.parse(input)
        parsedIdentifier = identifier

        await lookupBook(identifier: identifier)
    }

    // MARK: - Book Lookup

    @MainActor
    private func lookupBook(identifier: ParsedBookIdentifier) async {
        do {
            switch identifier {
            case .isbn(let isbn):
                try await lookupByISBN(isbn)
            case .openLibraryWork(let key):
                try await lookupByWorkKey(key)
            case .openLibraryEdition(let key):
                try await lookupByEditionKey(key)
            case .searchQuery(let query):
                try await lookupBySearch(query)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    @MainActor
    private func lookupByISBN(_ isbn: String) async throws {
        // Check if already in library
        if let existing = findExistingBook(isbn: isbn) {
            existingBook = existing
            selectedShelf = existing.shelf
            let info = BookInfo(
                olWorkKey: existing.olWorkKey,
                title: existing.title,
                author: existing.authorName,
                coverID: existing.coverImageID,
                firstPublishYear: existing.firstPublishYear,
                isbn13: existing.isbn13,
                isbn10: existing.isbn10,
                pageCount: existing.pageCount,
                subjects: existing.subjects
            )
            state = .alreadyInLibrary(info)
            return
        }

        let edition = try await client.lookupISBN(isbn)
        var workDetail: WorkDetail?
        var authorName = "Unknown Author"

        if let workKey = edition.workKey {
            workDetail = try? await client.fetchWorkDetail(key: workKey)
            if let authorKey = workDetail?.primaryAuthorKey {
                let author = try? await client.fetchAuthorDetail(key: authorKey)
                authorName = author?.name ?? "Unknown Author"
            }
        }

        let info = BookInfo(
            olWorkKey: edition.workKey ?? edition.key,
            title: workDetail?.title ?? edition.title,
            author: authorName,
            coverID: edition.primaryCoverID ?? workDetail?.primaryCoverID,
            firstPublishYear: nil,
            isbn13: edition.primaryISBN13,
            isbn10: edition.primaryISBN10,
            pageCount: edition.numberOfPages,
            subjects: workDetail?.subjects ?? []
        )
        state = .found(info)
    }

    @MainActor
    private func lookupByWorkKey(_ key: String) async throws {
        let detail = try await client.fetchWorkDetail(key: key)

        var authorName = "Unknown Author"
        if let authorKey = detail.primaryAuthorKey {
            let author = try? await client.fetchAuthorDetail(key: authorKey)
            authorName = author?.name ?? "Unknown Author"
        }

        let info = BookInfo(
            olWorkKey: detail.key,
            title: detail.title,
            author: authorName,
            coverID: detail.primaryCoverID,
            firstPublishYear: nil,
            isbn13: nil,
            isbn10: nil,
            pageCount: nil,
            subjects: detail.subjects ?? []
        )

        // Check if already in library
        if let existing = findExistingBookByWorkKey(detail.key) {
            existingBook = existing
            selectedShelf = existing.shelf
            state = .alreadyInLibrary(info)
        } else {
            state = .found(info)
        }
    }

    @MainActor
    private func lookupByEditionKey(_ key: String) async throws {
        // Edition keys like /books/OL12345M
        let editionURL = URL(string: "https://openlibrary.org\(key).json")!
        let (data, _) = try await URLSession.shared.data(from: editionURL)
        let edition = try JSONDecoder().decode(EditionDetail.self, from: data)

        if let isbn = edition.primaryISBN13 ?? edition.primaryISBN10 {
            try await lookupByISBN(isbn)
        } else if let workKey = edition.workKey {
            try await lookupByWorkKey(workKey)
        } else {
            state = .notFound
        }
    }

    @MainActor
    private func lookupBySearch(_ query: String) async throws {
        let results = try await client.search(query: query)

        guard let first = results.first else {
            state = .notFound
            return
        }

        let info = BookInfo(
            olWorkKey: first.key,
            title: first.title,
            author: first.primaryAuthor,
            coverID: first.coverI,
            firstPublishYear: first.firstPublishYear,
            isbn13: first.primaryISBN13,
            isbn10: first.primaryISBN10,
            pageCount: first.numberOfPagesMedian,
            subjects: first.subject ?? []
        )

        // Check if already in library
        if let existing = findExistingBookByWorkKey(first.key) {
            existingBook = existing
            selectedShelf = existing.shelf
            state = .alreadyInLibrary(info)
        } else {
            state = .found(info)
        }
    }

    // MARK: - Library queries

    @MainActor
    private func findExistingBook(isbn: String) -> Book? {
        guard let context = modelContainer?.mainContext else { return nil }

        // Try ISBN-13
        let descriptor13 = FetchDescriptor<Book>(
            predicate: #Predicate { $0.isbn13 == isbn }
        )
        if let found = (try? context.fetch(descriptor13))?.first {
            return found
        }

        // Try ISBN-10
        let descriptor10 = FetchDescriptor<Book>(
            predicate: #Predicate { $0.isbn10 == isbn }
        )
        return (try? context.fetch(descriptor10))?.first
    }

    @MainActor
    private func findExistingBookByWorkKey(_ key: String) -> Book? {
        guard let context = modelContainer?.mainContext else { return nil }

        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.olWorkKey == key }
        )
        return (try? context.fetch(descriptor))?.first
    }

    // MARK: - Save

    @MainActor
    private func saveBook(_ info: BookInfo) async {
        guard let context = modelContainer?.mainContext else {
            state = .error("Unable to access library.")
            return
        }

        isSaving = true

        let subjects = info.subjects
        let book = Book(
            olWorkKey: info.olWorkKey,
            isbn13: info.isbn13,
            isbn10: info.isbn10,
            title: info.title,
            authorName: info.author,
            coverImageID: info.coverID,
            pageCount: info.pageCount,
            firstPublishYear: info.firstPublishYear,
            subjects: subjects,
            shelf: selectedShelf,
            dateAdded: .now,
            format: BookFormat.detectFormat(subjects: subjects)
        )

        context.insert(book)
        try? context.save()

        isSaving = false
        dismissAction()
    }

    // MARK: - Update existing book

    @MainActor
    private func updateExistingBook() {
        guard let book = existingBook else { return }

        book.shelf = selectedShelf

        switch selectedShelf {
        case .reading:
            if book.dateStarted == nil {
                book.dateStarted = .now
            }
        case .read:
            if book.dateFinished == nil {
                book.dateFinished = .now
            }
        case .wantToRead:
            book.dateStarted = nil
            book.dateFinished = nil
            book.currentPage = nil
        case .dnf:
            break
        }

        try? modelContainer?.mainContext.save()
        dismissAction()
    }

    // MARK: - Open in Main App

    private func openInMainApp() {
        var urlString = "openshelf://search"

        switch parsedIdentifier {
        case .isbn(let isbn):
            urlString = "openshelf://book?isbn=\(isbn)"
        case .searchQuery(let query):
            if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString = "openshelf://search?q=\(encoded)"
            }
        case .openLibraryWork(let key):
            let stripped = key.hasPrefix("/") ? String(key.dropFirst()) : key
            urlString = "openshelf://book/\(stripped)"
        case .openLibraryEdition, .none:
            break
        }

        guard let url = URL(string: urlString) else { return }
        openURLAction(url)
    }
}

// MARK: - Supporting types

enum ShareState {
    case loading
    case found(BookInfo)
    case alreadyInLibrary(BookInfo)
    case notFound
    case error(String)
}

struct BookInfo {
    let olWorkKey: String
    let title: String
    let author: String
    let coverID: Int?
    let firstPublishYear: Int?
    let isbn13: String?
    let isbn10: String?
    let pageCount: Int?
    let subjects: [String]
}

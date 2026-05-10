import SwiftUI
import SwiftData

// MARK: - Curated List Model

struct CuratedList: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let bookKeys: [String]
}

// MARK: - Discover Section (horizontal scroll of curated lists)

struct DiscoverSection: View {
    @State private var lists: [CuratedList] = []

    var body: some View {
        if !lists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Discover")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(lists) { list in
                            NavigationLink {
                                CuratedListDetailView(list: list)
                            } label: {
                                curatedListCard(list)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func curatedListCard(_ list: CuratedList) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(list.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)

            Text(list.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text("\(list.bookKeys.count) \(list.bookKeys.count == 1 ? "book" : "books")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 160, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    init() {
        _lists = State(initialValue: Self.loadLists())
    }

    private static func loadLists() -> [CuratedList] {
        guard let url = Bundle.main.url(forResource: "CuratedLists", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lists = try? JSONDecoder().decode([CuratedList].self, from: data) else {
            return []
        }
        return lists
    }
}

// MARK: - Curated List Detail View

struct CuratedListDetailView: View {
    let list: CuratedList

    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Query private var libraryBooks: [Book]
    @Query private var dismissedBooks: [DismissedBook]

    @State private var fetchedBooks: [FetchedCuratedBook] = []
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    /// Books filtered to exclude dismissed titles and books already in the library.
    private var visibleBooks: [FetchedCuratedBook] {
        let dismissedKeys = Set(dismissedBooks.map(\.openLibraryWorkKey))
        let libraryKeys = Set(libraryBooks.map(\.olWorkKey))
        return fetchedBooks.filter { book in
            !dismissedKeys.contains(book.workKey) && !libraryKeys.contains(book.workKey)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(list.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if visibleBooks.isEmpty && !fetchedBooks.isEmpty {
                    ContentUnavailableView(
                        "All books dismissed",
                        systemImage: "hand.thumbsdown",
                        description: Text("You've dismissed all books in this list. Undo in Settings.")
                    )
                } else if visibleBooks.isEmpty {
                    ContentUnavailableView(
                        "No books available",
                        systemImage: "book.closed",
                        description: Text("Could not load books for this list.")
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visibleBooks) { book in
                            NavigationLink {
                                bookDestination(book)
                            } label: {
                                bookCell(book)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    dismissBook(book)
                                } label: {
                                    Label("Not Interested", systemImage: "hand.thumbsdown")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(list.name)
        .task { await loadBooks() }
    }

    @ViewBuilder
    private func bookDestination(_ book: FetchedCuratedBook) -> some View {
        if let libraryBook = libraryBooks.first(where: { $0.olWorkKey == book.workKey }) {
            BookDetailView(book: libraryBook)
        } else {
            let searchResult = SearchResult(
                key: book.workKey,
                title: book.title,
                authorName: book.author.map { [$0] },
                firstPublishYear: nil,
                numberOfPagesMedian: nil,
                coverI: book.coverID,
                editionCount: nil,
                isbn: nil,
                subject: book.subjects,
                idGoodreads: nil
            )
            BookDetailSheet(searchResult: searchResult, onAdded: {})
        }
    }

    private func bookCell(_ book: FetchedCuratedBook) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                CoverImage(coverID: book.coverID, size: .medium)
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                if libraryBooks.contains(where: { $0.olWorkKey == book.workKey && !$0.isPrivate }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white, .green)
                        .padding(4)
                }
            }

            Text(book.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 100)
        }
    }

    private func dismissBook(_ book: FetchedCuratedBook) {
        let dismissed = DismissedBook(
            openLibraryWorkKey: book.workKey,
            title: book.title,
            author: book.author ?? "Unknown Author"
        )
        withAnimation {
            modelContext.insert(dismissed)
            try? modelContext.save()
        }
    }

    private func loadBooks() async {
        isLoading = true
        defer { isLoading = false }

        let keys = list.bookKeys
        let repo = repository

        let results: [FetchedCuratedBook] = await withTaskGroup(
            of: (Int, FetchedCuratedBook?).self
        ) { group in
            for (index, key) in keys.enumerated() {
                group.addTask {
                    do {
                        let detail = try await repo.fetchDetail(for: key)
                        var authorName: String?
                        if let authorKey = detail.primaryAuthorKey {
                            let authorDetail = try? await repo.fetchAuthorDetail(key: authorKey)
                            authorName = authorDetail?.name
                        }
                        return (index, FetchedCuratedBook(
                            workKey: key,
                            title: detail.title,
                            coverID: detail.primaryCoverID,
                            subjects: detail.subjects,
                            author: authorName
                        ))
                    } catch {
                        return (index, nil)
                    }
                }
            }

            var indexed: [(Int, FetchedCuratedBook)] = []
            for await (index, book) in group {
                if let book {
                    indexed.append((index, book))
                }
            }
            return indexed
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }

        fetchedBooks = results
    }
}

// MARK: - Fetched Curated Book

struct FetchedCuratedBook: Identifiable {
    let workKey: String
    let title: String
    let coverID: Int?
    let subjects: [String]?
    let author: String?

    var id: String { workKey }
}

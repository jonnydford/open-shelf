import SwiftUI
import SwiftData

// MARK: - Curated List Models

struct CuratedBookEntry: Codable, Identifiable, Hashable {
    let workKey: String
    let title: String
    let author: String
    let coverID: Int?
    let subjects: [String]

    var id: String { workKey }

    var asSearchResult: SearchResult {
        SearchResult(
            key: workKey,
            title: title,
            authorName: [author],
            firstPublishYear: nil,
            numberOfPagesMedian: nil,
            coverI: coverID,
            editionCount: nil,
            isbn: nil,
            subject: subjects,
            idGoodreads: nil
        )
    }
}

enum CuratedListCategory: String, Codable, CaseIterable {
    case genre
    case collection

    var displayName: String {
        switch self {
        case .genre: "By Genre"
        case .collection: "Curated Collections"
        }
    }
}

struct CuratedList: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let category: CuratedListCategory
    let books: [CuratedBookEntry]
}

// MARK: - Discover Section (vertical grid of curated lists)

struct DiscoverSection: View {
    @State private var lists: [CuratedList] = []

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        if !lists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Curated Lists")
                    .font(.headline)
                    .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 12) {
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
    }

    private func curatedListCard(_ list: CuratedList) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(list.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text(list.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Text("^[\(list.books.count) book](inflect: true)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to view list")
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

    @Environment(\.modelContext) private var modelContext
    @Query private var libraryBooks: [Book]
    @Query private var dismissedBooks: [DismissedBook]

    @State private var selectedBook: CuratedBookEntry?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    private var dismissedKeys: Set<String> {
        Set(dismissedBooks.map(\.openLibraryWorkKey))
    }

    private var nonPrivateLibraryKeys: Set<String> {
        Set(libraryBooks.filter { !$0.isPrivate }.map(\.olWorkKey))
    }

    private var allLibraryKeys: Set<String> {
        Set(libraryBooks.map(\.olWorkKey))
    }

    private var visibleBooks: [CuratedBookEntry] {
        return list.books.filter { book in
            !dismissedKeys.contains(book.workKey) && !allLibraryKeys.contains(book.workKey)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(list.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if visibleBooks.isEmpty && !list.books.isEmpty {
                    ContentUnavailableView(
                        "You've explored everything here",
                        systemImage: "sparkles",
                        description: Text("All books in this list are in your library or dismissed.")
                    )
                } else if visibleBooks.isEmpty {
                    ContentUnavailableView(
                        "No books available",
                        systemImage: "book.closed",
                        description: Text("This list is currently empty.")
                    )
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visibleBooks) { book in
                            Group {
                                if let libraryBook = libraryBooks.first(where: { $0.olWorkKey == book.workKey }) {
                                    NavigationLink {
                                        BookDetailView(book: libraryBook)
                                    } label: {
                                        bookCell(book)
                                    }
                                } else {
                                    Button {
                                        selectedBook = book
                                    } label: {
                                        bookCell(book)
                                    }
                                }
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
        .sheet(item: $selectedBook) { book in
            BookDetailSheet(
                searchResult: book.asSearchResult,
                onAdded: {}
            )
        }
    }

    private func bookCell(_ book: CuratedBookEntry) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                CoverImage(coverID: book.coverID, size: .medium)
                    .frame(width: 100, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                if nonPrivateLibraryKeys.contains(book.workKey) {
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

            Text(book.author)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 100)
        }
        .accessibilityElement(children: .combine)
    }

    private func dismissBook(_ book: CuratedBookEntry) {
        let dismissed = DismissedBook(
            openLibraryWorkKey: book.workKey,
            title: book.title,
            author: book.author
        )
        withAnimation {
            modelContext.insert(dismissed)
            try? modelContext.save()
        }
    }
}


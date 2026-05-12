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

            Text("\(list.books.count) \(list.books.count == 1 ? "book" : "books")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 100)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .accessibilityElement(children: .combine)
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

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    private var visibleBooks: [CuratedBookEntry] {
        let dismissedKeys = Set(dismissedBooks.map(\.openLibraryWorkKey))
        let libraryKeys = Set(libraryBooks.map(\.olWorkKey))
        return list.books.filter { book in
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

                if visibleBooks.isEmpty && !list.books.isEmpty {
                    ContentUnavailableView(
                        "You've seen everything here",
                        systemImage: "sparkles",
                        description: Text("Check back later for new picks.")
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
    }

    @ViewBuilder
    private func bookDestination(_ book: CuratedBookEntry) -> some View {
        if let libraryBook = libraryBooks.first(where: { $0.olWorkKey == book.workKey }) {
            BookDetailView(book: libraryBook)
        } else {
            let searchResult = SearchResult(
                key: book.workKey,
                title: book.title,
                authorName: [book.author],
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

    private func bookCell(_ book: CuratedBookEntry) -> some View {
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


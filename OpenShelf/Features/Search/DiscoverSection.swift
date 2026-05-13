import SwiftUI
import SwiftData

// MARK: - Series Models

struct SeriesBookEntry: Codable, Identifiable, Hashable {
    let workKey: String
    let title: String
    let author: String
    let coverID: Int?
    let seriesPosition: Int

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
            subject: nil,
            idGoodreads: nil,
            ratingsAverage: nil,
            ratingsCount: nil,
            readinglogCount: nil,
            wantToReadCount: nil,
            currentlyReadingCount: nil,
            alreadyReadCount: nil,
            language: nil
        )
    }
}

struct FamousSeries: Codable, Identifiable {
    let id: String
    let name: String
    let author: String
    let books: [SeriesBookEntry]
}

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
            idGoodreads: nil,
            ratingsAverage: nil,
            ratingsCount: nil,
            readinglogCount: nil,
            wantToReadCount: nil,
            currentlyReadingCount: nil,
            alreadyReadCount: nil,
            language: nil
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

// MARK: - Discover Section (grouped horizontal-scroll layout)

struct DiscoverSection: View {
    @Environment(ReadingPromptService.self) private var readingPromptService
    @Environment(DiscoverRecommendationService.self) private var recommendationService
    @Environment(PopularBooksService.self) private var popularBooksService
    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext

    @Query private var libraryBooks: [Book]
    @Query private var dismissedBooks: [DismissedBook]

    @AppStorage("preferredLanguages") private var preferredLanguagesJSON: String = "[\"eng\"]"

    @State private var lists: [CuratedList] = []
    @State private var seriesList: [FamousSeries] = []
    @State private var selectedRecommendation: SearchResult?

    private var preferredLanguages: [String] {
        LanguageCode.decode(json: preferredLanguagesJSON)
    }

    private var groupedLists: [(category: CuratedListCategory, lists: [CuratedList])] {
        CuratedListCategory.allCases.compactMap { category in
            let matching = lists.filter { $0.category == category }
            return matching.isEmpty ? nil : (category, matching)
        }
    }

    private var libraryKeys: Set<String> {
        Set(libraryBooks.map(\.olWorkKey))
    }

    private var dismissedKeySet: Set<String> {
        Set(dismissedBooks.map(\.openLibraryWorkKey))
    }

    private var libraryGenreCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for book in libraryBooks where book.shelf == .read {
            let genre = StatsCalculator.classifyGenre(subjects: book.subjects)
            if genre != "Other" && genre != "Uncategorised" {
                counts[genre, default: 0] += 1
            }
        }
        return counts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            readingPromptBanner

            recommendationsSection

            popularSection

            famousSeriesSection

            ForEach(groupedLists, id: \.category) { group in
                VStack(alignment: .leading, spacing: 12) {
                    Text(group.category.displayName)
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(group.lists) { list in
                                NavigationLink {
                                    CuratedListDetailView(list: list)
                                } label: {
                                    curatedListCard(list)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal)
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
            }
        }
        .task(id: preferredLanguagesJSON) {
            let libKeys = libraryKeys
            let disKeys = dismissedKeySet
            let genreCounts = libraryGenreCounts
            await recommendationService.refreshIfNeeded(
                library: libraryBooks,
                dismissed: dismissedBooks,
                using: repository
            )
            await popularBooksService.refreshIfNeeded(
                libraryKeys: libKeys,
                dismissedKeys: disKeys,
                genreCounts: genreCounts,
                languages: preferredLanguages,
                using: repository
            )
        }
        .sheet(item: $selectedRecommendation) { result in
            BookDetailSheet(searchResult: result, onAdded: {})
        }
    }

    // MARK: - Reading Prompt Banner

    @ViewBuilder
    private var readingPromptBanner: some View {
        if let prompt = readingPromptService.currentPrompt {
            HStack(spacing: 12) {
                Image(systemName: prompt.systemImage)
                    .font(.title2)
                    .foregroundStyle(prompt.tintColor)
                    .accessibilityHidden(true)

                Text(prompt.message)
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(prompt.tintColor.opacity(0.1), in: RoundedRectangle(cornerRadius: CornerRadius.medium))
            .padding(.horizontal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Reading suggestion: \(prompt.message)")
            .transition(.opacity)
            .animation(.easeInOut, value: prompt.message)
            .task { await readingPromptService.refresh() }
        }
    }

    // MARK: - Recommendations

    @ViewBuilder
    private var recommendationsSection: some View {
        if !recommendationService.recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Recommended for You")
                    .font(.headline)
                    .padding(.horizontal)
                    .accessibilityAddTraits(.isHeader)

                ForEach(recommendationService.recommendations) { rec in
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .accessibilityAddTraits(.isHeader)
                            Text(rec.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(rec.books) { book in
                                    Button {
                                        selectedRecommendation = book
                                    } label: {
                                        discoverBookCard(book)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Double tap to view details")
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            dismissRecommendedBook(book)
                                        } label: {
                                            Label("Not Interested", systemImage: "hand.thumbsdown")
                                        }
                                    }
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.horizontal)
                        }
                        .scrollTargetBehavior(.viewAligned)
                    }
                }
            }
        } else if recommendationService.isLoading {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommended for You")
                    .font(.headline)
                    .padding(.horizontal)
                    .accessibilityAddTraits(.isHeader)

                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .accessibilityLabel("Loading recommendations")
            }
        }
    }

    // MARK: - Popular

    @ViewBuilder
    private var popularSection: some View {
        if !popularBooksService.sections.isEmpty {
            ForEach(popularBooksService.sections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Most Read in \(section.genre)")
                        .font(.headline)
                        .padding(.horizontal)
                        .accessibilityAddTraits(.isHeader)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(section.books) { book in
                                Button {
                                    selectedRecommendation = book
                                } label: {
                                    discoverBookCard(book, showReaderCount: true)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Double tap to view details")
                                .contextMenu {
                                    Button(role: .destructive) {
                                        dismissRecommendedBook(book)
                                    } label: {
                                        Label("Not Interested", systemImage: "hand.thumbsdown")
                                    }
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal)
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
            }
        } else if popularBooksService.isLoading {
            VStack(alignment: .leading, spacing: 12) {
                Text("Most Read")
                    .font(.headline)
                    .padding(.horizontal)
                    .accessibilityAddTraits(.isHeader)

                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .accessibilityLabel("Loading popular books")
            }
        }
    }

    // MARK: - Shared Book Card

    private func discoverBookCard(_ book: SearchResult, showReaderCount: Bool = false) -> some View {
        VStack(spacing: 6) {
            CoverImage(coverID: book.coverI, size: .medium)
                .frame(width: 100, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            Text(book.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 100)

            Text(book.primaryAuthor)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 100)

            if showReaderCount, let count = book.readinglogCount, count > 0 {
                Text("\(Self.formatCount(count)) readers")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    static func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            let value = Double(count) / 1_000_000
            return value >= 10 ? "\(Int(value))M" : String(format: "%.1fM", value)
        } else if count >= 1_000 {
            let value = Double(count) / 1_000
            return value >= 100 ? "\(Int(value))K" : String(format: "%.1fK", value)
        }
        return "\(count)"
    }

    private func dismissRecommendedBook(_ book: SearchResult) {
        guard repository.existingDismissedBook(forWorkKey: book.key) == nil else { return }
        let dismissed = DismissedBook(
            openLibraryWorkKey: book.key,
            title: book.title,
            author: book.authorName?.first ?? "Unknown Author"
        )
        withAnimation {
            modelContext.insert(dismissed)
            try? modelContext.save()
        }
    }

    private func curatedListCard(_ list: CuratedList) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            coverGrid(list.books)

            Text(list.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("^[\(list.books.count) book](inflect: true)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(list.name), \(list.description), \(list.books.count) books")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to view list")
    }

    private func coverGrid(_ books: [CuratedBookEntry]) -> some View {
        let covers = Array(books.prefix(4))
        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                coverCell(covers.indices.contains(0) ? covers[0] : nil)
                coverCell(covers.indices.contains(1) ? covers[1] : nil)
            }
            HStack(spacing: 4) {
                coverCell(covers.indices.contains(2) ? covers[2] : nil)
                coverCell(covers.indices.contains(3) ? covers[3] : nil)
            }
        }
        .padding(2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    @ViewBuilder
    private func coverCell(_ book: CuratedBookEntry?) -> some View {
        if let book {
            CoverImage(coverID: book.coverID, size: .medium)
                .frame(width: 76, height: 114)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xSmall))
        } else {
            RoundedRectangle(cornerRadius: CornerRadius.xSmall)
                .fill(.quaternary)
                .frame(width: 76, height: 114)
        }
    }

    init() {
        _lists = State(initialValue: Self.loadLists())
        _seriesList = State(initialValue: Self.loadSeries())
    }

    private static func loadLists() -> [CuratedList] {
        guard let url = Bundle.main.url(forResource: "CuratedLists", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lists = try? JSONDecoder().decode([CuratedList].self, from: data) else {
            return []
        }
        return lists
    }

    private static func loadSeries() -> [FamousSeries] {
        guard let url = Bundle.main.url(forResource: "FamousSeries", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let series = try? JSONDecoder().decode([FamousSeries].self, from: data) else {
            return []
        }
        return series
    }

    // MARK: - Famous Series

    @ViewBuilder
    private var famousSeriesSection: some View {
        if !seriesList.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Famous Series")
                    .font(.headline)
                    .padding(.horizontal)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(seriesList) { series in
                            NavigationLink {
                                SeriesDetailView(series: series)
                            } label: {
                                seriesCard(series)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }

    private func seriesCard(_ series: FamousSeries) -> some View {
        let readKeys = Set(libraryBooks.filter { $0.shelf == .read }.map(\.olWorkKey))
        let readCount = series.books.filter { readKeys.contains($0.workKey) }.count

        return VStack(alignment: .leading, spacing: 8) {
            seriesCoverGrid(series.books)

            Text(series.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(series.author)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if readCount > 0 {
                Text("\(readCount) of \(series.books.count) read")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                Text("^[\(series.books.count) book](inflect: true)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 160)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(series.name) by \(series.author), \(readCount) of \(series.books.count) read")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to view series")
    }

    private func seriesCoverGrid(_ books: [SeriesBookEntry]) -> some View {
        let covers = Array(books.prefix(4))
        return VStack(spacing: 4) {
            HStack(spacing: 4) {
                seriesCoverCell(covers.indices.contains(0) ? covers[0] : nil)
                seriesCoverCell(covers.indices.contains(1) ? covers[1] : nil)
            }
            HStack(spacing: 4) {
                seriesCoverCell(covers.indices.contains(2) ? covers[2] : nil)
                seriesCoverCell(covers.indices.contains(3) ? covers[3] : nil)
            }
        }
        .padding(2)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    @ViewBuilder
    private func seriesCoverCell(_ book: SeriesBookEntry?) -> some View {
        if let book {
            CoverImage(coverID: book.coverID, size: .medium)
                .frame(width: 76, height: 114)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xSmall))
        } else {
            RoundedRectangle(cornerRadius: CornerRadius.xSmall)
                .fill(.quaternary)
                .frame(width: 76, height: 114)
        }
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
        let key = book.workKey
        let descriptor = FetchDescriptor<DismissedBook>(
            predicate: #Predicate { $0.openLibraryWorkKey == key }
        )
        guard (try? modelContext.fetch(descriptor))?.first == nil else { return }
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

// MARK: - Series Detail View

struct SeriesDetailView: View {
    let series: FamousSeries

    @Query private var libraryBooks: [Book]

    @State private var selectedBook: SeriesBookEntry?

    private var libraryKeys: Set<String> {
        Set(libraryBooks.map(\.olWorkKey))
    }

    private var nonPrivateLibraryKeys: Set<String> {
        Set(libraryBooks.filter { !$0.isPrivate }.map(\.olWorkKey))
    }

    private var sortedBooks: [SeriesBookEntry] {
        series.books.sorted { $0.seriesPosition < $1.seriesPosition }
    }

    var body: some View {
        List {
            ForEach(sortedBooks) { book in
                Group {
                    if let libraryBook = libraryBooks.first(where: { $0.olWorkKey == book.workKey }) {
                        NavigationLink {
                            BookDetailView(book: libraryBook)
                        } label: {
                            seriesBookRow(book)
                        }
                        .accessibilityHint("Double tap to view in library")
                    } else {
                        Button {
                            selectedBook = book
                        } label: {
                            seriesBookRow(book)
                        }
                        .accessibilityHint("Double tap to view details")
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(series.name)
        .sheet(item: $selectedBook) { book in
            BookDetailSheet(
                searchResult: book.asSearchResult,
                onAdded: {}
            )
        }
    }

    private func seriesBookRow(_ book: SeriesBookEntry) -> some View {
        HStack(spacing: 12) {
            Text("\(book.seriesPosition)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            CoverImage(coverID: book.coverID, size: .small)
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if nonPrivateLibraryKeys.contains(book.workKey) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, .green)
                    .accessibilityLabel("In library")
            }
        }
        .accessibilityElement(children: .combine)
    }
}


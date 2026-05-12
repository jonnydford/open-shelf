import SwiftUI
import SwiftData

struct SearchView: View {
    @Binding var prefillQuery: String?

    @Environment(BookRepository.self) private var repository
    @AppStorage("searchHistory") private var searchHistoryData: String = "[]"
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @State private var showManualEntry = false
    @State private var isSearchPresented = false
    @State private var navigationPath = NavigationPath()

    @Query private var allLibraryBooks: [Book]

    private var searchHistory: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(searchHistoryData.utf8))) ?? []
    }

    private func saveToHistory(_ query: String) {
        var history = searchHistory
        history.removeAll { $0.lowercased() == query.lowercased() }
        history.insert(query, at: 0)
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
        if let data = try? JSONEncoder().encode(history),
           let json = String(data: data, encoding: .utf8) {
            searchHistoryData = json
        }
    }

    private func clearHistory() {
        searchHistoryData = "[]"
    }

    init(prefillQuery: Binding<String?> = .constant(nil)) {
        self._prefillQuery = prefillQuery
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if let errorMessage {
                    errorState(message: errorMessage)
                } else if results.isEmpty && !isSearching && !hasSearched {
                    initialState
                } else if results.isEmpty && !isSearching && hasSearched {
                    noResultsState
                } else if isSearching && results.isEmpty {
                    loadingState
                } else {
                    resultsList
                }
            }
            .navigationTitle("Discover")
            .searchable(text: $searchText, isPresented: $isSearchPresented, placement: .navigationBarDrawer(displayMode: .always), prompt: "Title, author, or ISBN")
            .searchSuggestions {
                if searchText.isEmpty && !searchHistory.isEmpty {
                    ForEach(searchHistory, id: \.self) { query in
                        Label(query, systemImage: "clock")
                            .searchCompletion(query)
                    }

                    Button("Clear History") {
                        clearHistory()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .accessibilityHint("Removes all saved searches")
                }
            }
            .navigationDestination(for: SearchResult.self) { result in
                if let existingBook = allLibraryBooks.first(where: { $0.olWorkKey == result.key }) {
                    BookDetailView(book: existingBook)
                } else {
                    SearchResultDetailView(searchResult: result)
                }
            }
            .onChange(of: searchText) {
                searchTask?.cancel()

                let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else {
                    results = []
                    hasSearched = false
                    errorMessage = nil
                    return
                }

                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await performSearch()
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView()
            }
            .onChange(of: prefillQuery) { _, newValue in
                if let query = newValue, !query.isEmpty {
                    searchText = query
                    prefillQuery = nil
                }
            }
        }
    }

    // MARK: - States

    private var initialState: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack(spacing: 8) {
                    Image(systemName: "books.vertical")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Search millions of books on Open Library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                DiscoverSection()
            }
            .padding(.top, 8)
        }
    }

    private var noResultsState: some View {
        ContentUnavailableView {
            Label("No Books Found", systemImage: "book.closed")
        } description: {
            Text("No books found for '\(searchText)'. Try a different search.")
        } actions: {
            Button("Add Manually") {
                showManualEntry = true
            }
        }
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView(
            "Search Unavailable",
            systemImage: "wifi.exclamationmark",
            description: Text(message)
        )
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel("Searching for books")
            Text("Searching...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            ForEach(results) { result in
                Button {
                    isSearchPresented = false
                    navigationPath.append(result)
                } label: {
                    searchResultRow(result)
                }
                .tint(.primary)
                .accessibilityHint("Double tap to view book details")
            }

            Section {
                Button {
                    showManualEntry = true
                } label: {
                    Label("Can't find your book? Add it manually", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            if isSearching {
                VStack {
                    ProgressView()
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.small))
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }

    private func searchResultRow(_ result: SearchResult) -> some View {
        HStack(spacing: 12) {
            CoverImage(coverID: result.coverI, size: .small)
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xSmall))

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(result.primaryAuthor)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let rating = result.ratingsAverage,
                       let ratingCount = result.ratingsCount,
                       ratingCount >= 5 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                            Text(String(format: "%.1f", rating))
                            Text("(\(ratingCount))")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Rated \(String(format: "%.1f", rating)) from \(ratingCount) ratings")
                    }

                    if let count = result.readinglogCount, count > 0 {
                        Text("\(DiscoverSection.formatCount(count)) readers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let year = result.firstPublishYear {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Search

    private func performSearch() async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        let query = searchText.trimmingCharacters(in: .whitespaces)

        do {
            let searchResults = try await repository.search(query: query)
            guard !Task.isCancelled else { return }
            results = searchResults
            hasSearched = true
            if !query.isEmpty {
                saveToHistory(query)
            }
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            hasSearched = true
            errorMessage = "Search unavailable \u{2014} check your connection."
        }
    }
}

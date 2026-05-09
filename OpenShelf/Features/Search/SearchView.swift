import SwiftUI

struct SearchView: View {
    @Environment(BookRepository.self) private var repository
    @State private var searchText = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty && !isSearching {
                    ContentUnavailableView(
                        "Search Open Library",
                        systemImage: "magnifyingglass",
                        description: Text("Find books by title, author, or ISBN.")
                    )
                } else if isSearching {
                    ProgressView("Searching...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(.headline)
                                .lineLimit(2)
                            Text(result.primaryAuthor)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let year = result.firstPublishYear {
                                Text(String(year))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Title, author, or ISBN")
            .onChange(of: searchText) {
                searchTask?.cancel()
                guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
                    results = []
                    return
                }
                searchTask = Task {
                    // 300ms debounce
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await performSearch()
                }
            }
        }
    }

    private func performSearch() async {
        isSearching = true
        defer { isSearching = false }

        do {
            let searchResults = try await repository.search(query: searchText)
            guard !Task.isCancelled else { return }
            results = searchResults
        } catch {
            guard !Task.isCancelled else { return }
            results = []
        }
    }
}

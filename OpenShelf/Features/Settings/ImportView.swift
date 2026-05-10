import SwiftUI
import UniformTypeIdentifiers

// MARK: - Import State

enum ImportState: Equatable {
    case instructions
    case picking
    case parsing
    case matching(current: Int, total: Int)
    case complete(matched: Int, unmatched: Int, errors: [String])
    case error(String)

    static func == (lhs: ImportState, rhs: ImportState) -> Bool {
        switch (lhs, rhs) {
        case (.instructions, .instructions): return true
        case (.picking, .picking): return true
        case (.parsing, .parsing): return true
        case (.matching(let lc, let lt), .matching(let rc, let rt)):
            return lc == rc && lt == rt
        case (.complete(let lm, let lu, _), .complete(let rm, let ru, _)):
            return lm == rm && lu == ru
        case (.error(let l), .error(let r)):
            return l == r
        default: return false
        }
    }
}

// MARK: - Import View

struct ImportView: View {
    @Environment(BookRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var importState: ImportState = .instructions
    @State private var showDocumentPicker = false
    @State private var importTask: Task<Void, Never>?
    @State private var selectedUnmatchedBook: String?
    @State private var resolvedBooks: Set<String> = []

    var body: some View {
        NavigationStack {
            Group {
                switch importState {
                case .instructions:
                    instructionsContent
                case .picking:
                    instructionsContent
                case .parsing:
                    parsingContent
                case .matching(let current, let total):
                    matchingContent(current: current, total: total)
                case .complete(let matched, let unmatched, let errors):
                    completeContent(matched: matched, unmatched: unmatched, errors: errors)
                case .error(let message):
                    errorContent(message: message)
                }
            }
            .navigationTitle("Import from Goodreads")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [UTType.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .onDisappear {
                importTask?.cancel()
                importTask = nil
            }
        }
    }

    // MARK: - Instructions

    private var instructionsContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.down")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .padding(.top, 32)

                Text("Import Your Goodreads Library")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 16) {
                    instructionStep(number: 1, text: "Go to goodreads.com and sign in")
                    instructionStep(number: 2, text: "Navigate to My Books")
                    instructionStep(number: 3, text: "Click Import and Export (left sidebar)")
                    instructionStep(number: 4, text: "Click Export Library to download your CSV")
                    instructionStep(number: 5, text: "Select the downloaded CSV file below")
                }
                .padding(.horizontal)

                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Select CSV File", systemImage: "doc")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Text("Your data stays on this device. The CSV file is only used to match books against Open Library.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.tint, in: Circle())

            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Parsing

    private var parsingContent: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Parsing CSV file...")
                .font(.headline)
            Text("Reading your Goodreads export")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Matching

    private func matchingContent(current: Int, total: Int) -> some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView(value: Double(current), total: Double(total))
                .padding(.horizontal, 40)
                .accessibilityLabel("Import progress: \(current) of \(total) books matched")

            Text("Matching books...")
                .font(.headline)

            Text("\(current) of \(total)")
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()

            let estimate = estimateTimeRemaining(current: current, total: total)
            if !estimate.isEmpty {
                Text(estimate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Looking up books via Open Library API")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func estimateTimeRemaining(current: Int, total: Int) -> String {
        let remaining = total - current
        guard remaining > 0 else { return "" }
        // ~3 requests/sec, so roughly 1/3 second per book
        let seconds = Double(remaining) / 3.0
        if seconds < 60 {
            return "About \(Int(seconds)) seconds remaining"
        } else {
            let minutes = Int(ceil(seconds / 60.0))
            return "About \(minutes) minute\(minutes == 1 ? "" : "s") remaining"
        }
    }

    // MARK: - Complete

    private func completeContent(matched: Int, unmatched: Int, errors: [String]) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                    .padding(.top, 32)

                Text("Import Complete")
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 32) {
                    VStack {
                        Text("\(matched)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Imported")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let remainingUnmatched = errors.filter { !resolvedBooks.contains($0) }.count
                    if remainingUnmatched > 0 {
                        VStack {
                            Text("\(remainingUnmatched)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                            Text("Not matched")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !errors.isEmpty {
                    let unresolvedErrors = errors.filter { !resolvedBooks.contains($0) }
                    if !unresolvedErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Unmatched Books")
                                .font(.headline)
                            Text("Tap to search, or skip.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(unresolvedErrors, id: \.self) { bookDescription in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bookDescription)
                                            .font(.subheadline)
                                    }
                                    Spacer()
                                    Button("Skip") {
                                        resolvedBooks.insert(bookDescription)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    Image(systemName: "magnifyingglass")
                                        .font(.caption)
                                        .foregroundStyle(.tint)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedUnmatchedBook = bookDescription
                                }

                                if bookDescription != unresolvedErrors.last {
                                    Divider()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }
                }

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(.bottom, 32)
        }
        .sheet(item: $selectedUnmatchedBook) { bookDescription in
            UnmatchedBookSearchSheet(bookDescription: bookDescription) {
                resolvedBooks.insert(bookDescription)
            }
        }
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)

            Text("Import Failed")
                .font(.title2)
                .fontWeight(.bold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                importState = .instructions
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    // MARK: - File Handling

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importState = .error("No file selected.")
                return
            }

            importTask?.cancel()
            importTask = Task {
                await processCSVFile(at: url)
            }

        case .failure(let error):
            importState = .error("Could not access file: \(error.localizedDescription)")
        }
    }

    private func processCSVFile(at url: URL) async {
        importState = .parsing

        // Access security-scoped resource
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)

            let result = try await repository.importFromGoodreads(csv: data) { current, total in
                await MainActor.run {
                    importState = .matching(current: current, total: total)
                }
            }

            guard !Task.isCancelled else { return }

            importState = .complete(
                matched: result.matchedCount,
                unmatched: result.unmatchedCount,
                errors: result.errors
            )
        } catch is CancellationError {
            // Import was cancelled; do nothing
        } catch let error as ImportError {
            guard !Task.isCancelled else { return }
            switch error {
            case .invalidCSV:
                importState = .error("The file does not appear to be a valid CSV.")
            case .parsingFailed(let detail):
                importState = .error("Parsing failed: \(detail)")
            case .notImplemented:
                importState = .error("Import is not yet available.")
            }
        } catch {
            guard !Task.isCancelled else { return }
            importState = .error("An unexpected error occurred: \(error.localizedDescription)")
        }
    }
}

// MARK: - String Identifiable conformance for sheet binding

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - Unmatched Book Search Sheet

struct UnmatchedBookSearchSheet: View {
    let bookDescription: String
    let onResolved: () -> Void

    @Environment(BookRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var results: [SearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedResult: SearchResult?

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty && !isSearching && !hasSearched {
                    ContentUnavailableView(
                        "Search Open Library",
                        systemImage: "magnifyingglass",
                        description: Text("Find the correct match for \"\(bookDescription)\".")
                    )
                } else if results.isEmpty && !isSearching && hasSearched {
                    ContentUnavailableView(
                        "No Books Found",
                        systemImage: "book.closed",
                        description: Text("No results for '\(searchText)'. Try a different search.")
                    )
                } else if isSearching && results.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Searching...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(results) { result in
                        Button {
                            selectedResult = result
                        } label: {
                            HStack(spacing: 12) {
                                CoverImage(coverID: result.coverI, size: .small)
                                    .frame(width: 50, height: 75)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.headline)
                                        .lineLimit(2)
                                    Text(result.primaryAuthor)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Resolve Match")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Title, author, or ISBN")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Pre-fill search with the book title (strip "by Author" suffix)
                let titlePart = bookDescription.components(separatedBy: " by ").first ?? bookDescription
                searchText = titlePart
            }
            .onChange(of: searchText) {
                searchTask?.cancel()
                let trimmed = searchText.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else {
                    results = []
                    hasSearched = false
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await performSearch()
                }
            }
            .sheet(item: $selectedResult) { result in
                BookDetailSheet(searchResult: result) {
                    onResolved()
                    dismiss()
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
            hasSearched = true
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            hasSearched = true
        }
    }
}

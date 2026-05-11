import SwiftUI
import SwiftData

/// A full push-navigation detail view for search results that are not yet in the library.
/// Replaces the former sheet-based BookDetailSheet flow from SearchView (#117).
struct SearchResultDetailView: View {
    let searchResult: SearchResult

    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var workDetail: WorkDetail?
    @State private var isLoadingDetail = true
    @State private var selectedShelf: Shelf = .wantToRead
    @State private var isAdding = false
    @State private var showRatingPrompt = false
    @State private var rating: Double?
    @State private var addedBook: Book?

    @ScaledMetric(relativeTo: .body) private var coverWidth: CGFloat = 200
    @ScaledMetric(relativeTo: .body) private var coverHeight: CGFloat = 300

    @Query private var allLibraryBooks: [Book]

    private var existingBook: Book? {
        allLibraryBooks.first { $0.olWorkKey == searchResult.key }
    }

    var body: some View {
        Group {
            if let book = existingBook ?? addedBook {
                BookDetailView(book: book)
            } else {
                searchResultContent
            }
        }
        .task {
            await loadDetail()
        }
    }

    private var searchResultContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                coverSection
                metadataSection

                if isLoadingDetail {
                    ProgressView()
                        .padding()
                } else {
                    synopsisSection
                    subjectsSection
                }

                Divider()
                    .padding(.horizontal)

                addToLibrarySection
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(searchResult.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRatingPrompt) {
            ratingSheet
        }
    }

    // MARK: - Cover Section

    private var coverSection: some View {
        CoverImage(coverID: searchResult.coverI, size: .large)
            .frame(width: coverWidth, height: coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .shadow(radius: 4)
            .padding(.top, 16)
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(spacing: 6) {
            Text(searchResult.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(searchResult.primaryAuthor)
                .font(.title3)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                if let year = searchResult.firstPublishYear {
                    Label(String(year), systemImage: "calendar")
                }

                if let pages = searchResult.numberOfPagesMedian {
                    Label("\(pages) pages", systemImage: "book.pages")
                }

                if let editions = searchResult.editionCount {
                    Label("\(editions) editions", systemImage: "square.stack")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Synopsis Section

    @ViewBuilder
    private var synopsisSection: some View {
        if let synopsis = workDetail?.synopsis, !synopsis.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Synopsis")
                    .font(.headline)

                Text(synopsis)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    // MARK: - Subjects Section

    @ViewBuilder
    private var subjectsSection: some View {
        let subjects = workDetail?.subjects ?? searchResult.subject ?? []
        let displaySubjects = Array(subjects.prefix(10))
        if !displaySubjects.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Subjects")
                    .font(.headline)

                FlowLayout(spacing: 6) {
                    ForEach(displaySubjects, id: \.self) { subject in
                        Text(subject)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.quaternary)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    // MARK: - Add to Library Section

    private var addToLibrarySection: some View {
        VStack(spacing: 12) {
            Picker("Shelf", selection: $selectedShelf) {
                ForEach(Shelf.allCases, id: \.self) { shelf in
                    Label(shelf.displayName, systemImage: shelf.systemImage)
                        .tag(shelf)
                }
            }
            .pickerStyle(.menu)

            Button {
                handleAdd()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add to \(selectedShelf.displayName)")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
            .disabled(isAdding)
            .padding(.horizontal)
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

                Text("You marked this as Read. Would you like to rate it?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                RatingPicker(rating: $rating, mode: .interactive)

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        addBookToLibrary(rating: nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Rating") {
                        addBookToLibrary(rating: rating)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func loadDetail() async {
        defer { isLoadingDetail = false }

        do {
            workDetail = try await repository.fetchDetail(for: searchResult.key)
        } catch {
            // Non-critical
        }
    }

    private func handleAdd() {
        if selectedShelf == .read {
            showRatingPrompt = true
        } else {
            addBookToLibrary(rating: nil)
        }
    }

    private func addBookToLibrary(rating: Double?) {
        isAdding = true

        repository.addBook(from: searchResult, detail: workDetail, shelf: selectedShelf)

        // Clean up any existing DismissedBook record for this work
        let dismissedKey = searchResult.key
        let dismissedDescriptor = FetchDescriptor<DismissedBook>(
            predicate: #Predicate { $0.openLibraryWorkKey == dismissedKey }
        )
        if let existingDismissed = try? modelContext.fetch(dismissedDescriptor).first {
            modelContext.delete(existingDismissed)
        }

        // Apply shelf-specific dates and rating via repository helpers
        let key = searchResult.key
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.olWorkKey == key }
        )
        if let book = (try? modelContext.fetch(descriptor))?.first {
            repository.updateShelf(book, to: selectedShelf)
            if let rating {
                repository.updateRating(book, rating: rating)
            }
            addedBook = book
        }
    }
}

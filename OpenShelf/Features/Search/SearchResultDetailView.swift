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
    @State private var workRatings: WorkRatings?
    @State private var workBookshelves: WorkBookshelves?

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

                communityStatsSection

                if isLoadingDetail {
                    ProgressView()
                        .padding()
                } else {
                    synopsisSection
                    subjectsSection
                }

                BuyLinksSection(isbn: searchResult.primaryISBN13 ?? searchResult.primaryISBN10)

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

    // MARK: - Community Stats Section

    @ViewBuilder
    private var communityStatsSection: some View {
        let hasRating = workRatings != nil || searchResult.ratingsAverage != nil
        let hasShelves = workBookshelves != nil

        if hasRating || hasShelves {
            VStack(spacing: 12) {
                if let ratings = workRatings {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.orange)
                            Text(String(format: "%.1f", ratings.summary.average))
                                .fontWeight(.semibold)
                            Text("(\(ratings.summary.count) ratings)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)

                        ratingBreakdown(ratings.counts)
                    }
                } else if let avg = searchResult.ratingsAverage,
                          let count = searchResult.ratingsCount {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.orange)
                        Text(String(format: "%.1f", avg))
                            .fontWeight(.semibold)
                        Text("(\(count) ratings)")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }

                if let shelves = workBookshelves {
                    HStack(spacing: 16) {
                        shelfStat(
                            count: shelves.counts.wantToRead,
                            label: "want to read"
                        )
                        shelfStat(
                            count: shelves.counts.currentlyReading,
                            label: "reading"
                        )
                        shelfStat(
                            count: shelves.counts.alreadyRead,
                            label: "read"
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .accessibilityElement(children: .combine)
        }
    }

    private func ratingBreakdown(_ counts: WorkRatings.RatingCounts) -> some View {
        let bars: [(label: String, count: Int)] = [
            ("5", counts.five),
            ("4", counts.four),
            ("3", counts.three),
            ("2", counts.two),
            ("1", counts.one),
        ]
        let maxCount = bars.map(\.count).max() ?? 1

        return VStack(spacing: 2) {
            ForEach(bars, id: \.label) { bar in
                HStack(spacing: 4) {
                    Text(bar.label)
                        .font(.caption2)
                        .frame(width: 12, alignment: .trailing)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.orange.opacity(0.6))
                            .frame(
                                width: maxCount > 0
                                    ? geo.size.width * CGFloat(bar.count) / CGFloat(maxCount)
                                    : 0
                            )
                    }
                    .frame(height: 8)

                    Text("\(bar.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 30, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func shelfStat(count: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(DiscoverSection.formatCount(count))
                .fontWeight(.medium)
            Text(label)
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

        async let ratingsTask: Void = {
            self.workRatings = try? await repository.fetchRatings(workKey: searchResult.key)
        }()
        async let shelvesTask: Void = {
            self.workBookshelves = try? await repository.fetchBookshelves(workKey: searchResult.key)
        }()
        _ = await (ratingsTask, shelvesTask)
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
        defer { isAdding = false }

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
            if selectedShelf == .read {
                repository.updateShelf(book, to: .read)
                let entry = ReadEntry(
                    book: book,
                    startDate: nil,
                    finishDate: .now,
                    rating: rating
                )
                modelContext.insert(entry)
            }
            if let rating {
                repository.updateRating(book, rating: rating)
            }
            addedBook = book
        }
    }
}

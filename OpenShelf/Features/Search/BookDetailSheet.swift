import SwiftUI
import SwiftData

struct BookDetailSheet: View {
    let searchResult: SearchResult
    let onAdded: () -> Void

    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var workDetail: WorkDetail?
    @State private var isLoadingDetail = true
    @State private var selectedShelf: Shelf = .wantToRead
    @State private var isAdding = false
    @State private var showRatingPrompt = false
    @State private var rating: Double = 0
    @State private var alreadyInLibrary = false

    var body: some View {
        NavigationStack {
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

                    addToShelfSection
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadDetail()
                checkDuplicate()
            }
            .alert("Rate This Book", isPresented: $showRatingPrompt) {
                Button("Skip") {
                    addBookToLibrary(rating: nil)
                }
                Button("Save Rating") {
                    addBookToLibrary(rating: rating)
                }
            } message: {
                Text("You marked this as Read. Would you like to rate it?")
            }
            // Rating picker shown via overlay when rating prompt is active
            .overlay {
                if showRatingPrompt {
                    ratingOverlay
                }
            }
        }
    }

    // MARK: - Cover Section

    private var coverSection: some View {
        CoverImage(coverID: searchResult.coverI, size: .large)
            .frame(width: 180, height: 270)
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
        let synopsis = workDetail?.synopsis ?? searchResult.synopsis
        if let synopsis, !synopsis.isEmpty {
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

    // MARK: - Add to Shelf Section

    private var addToShelfSection: some View {
        VStack(spacing: 12) {
            if alreadyInLibrary {
                Label("Already in your library", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .padding()
            } else {
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isAdding)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Rating Overlay

    private var ratingOverlay: some View {
        Color.clear
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                VStack(spacing: 16) {
                    Text("Rate This Book")
                        .font(.headline)
                    RatingPicker(rating: $rating)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .allowsHitTesting(false)
    }

    // MARK: - Actions

    private func loadDetail() async {
        defer { isLoadingDetail = false }

        do {
            workDetail = try await repository.fetchDetail(for: searchResult.key)
        } catch {
            // Non-critical — we can still show the book with search result data
        }
    }

    private func checkDuplicate() {
        let key = searchResult.key
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.olWorkKey == key }
        )
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        alreadyInLibrary = !existing.isEmpty
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

        // Apply shelf-specific logic
        if selectedShelf == .reading {
            // dateStarted is set by addBook indirectly via updateShelf logic,
            // but addBook sets it via init. Let's update the most recently added book.
            let key = searchResult.key
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate { $0.olWorkKey == key }
            )
            if let book = (try? modelContext.fetch(descriptor))?.first {
                if selectedShelf == .reading {
                    book.dateStarted = .now
                }
                if selectedShelf == .read {
                    book.dateFinished = .now
                }
                if let rating, rating > 0 {
                    book.userRating = rating
                }
                try? modelContext.save()
            }
        } else if selectedShelf == .read || rating != nil {
            let key = searchResult.key
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate { $0.olWorkKey == key }
            )
            if let book = (try? modelContext.fetch(descriptor))?.first {
                book.dateFinished = .now
                if let rating, rating > 0 {
                    book.userRating = rating
                }
                try? modelContext.save()
            }
        }

        onAdded()
        dismiss()
    }
}

// MARK: - SearchResult Extension

private extension SearchResult {
    var synopsis: String? { nil }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var size: CGSize
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        return LayoutResult(
            positions: positions,
            size: CGSize(width: totalWidth, height: currentY + lineHeight)
        )
    }
}

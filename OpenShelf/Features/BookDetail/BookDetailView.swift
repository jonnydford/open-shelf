import SwiftUI
import SwiftData

struct BookDetailView: View {
    let book: Book

    @Environment(BookRepository.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var synopsisExpanded = false
    @State private var showProgressEditor = false
    @State private var showDeleteConfirmation = false
    @State private var showDNFSheet = false
    @State private var showShelfPicker = false
    @State private var showFinishedRating = false
    @State private var finishedRating: Double?

    // DNF state
    @State private var dnfPage: String = ""
    @State private var dnfReason: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Social/sharing state
    @State private var showShareCardSheet = false
    @State private var showRecommendSheet = false
    @State private var shareCardItems: [Any] = []
    @State private var recommendText: String = ""
    @State private var showAddToListSheet = false
    @State private var coverImageForShare: UIImage?

    @Query(sort: \ReadingList.dateCreated, order: .reverse) private var readingLists: [ReadingList]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                userSection
                progressSection
                synopsisSection
                detailsSection
                NotesEditor(book: book)
                    .padding(.horizontal)
                ReadHistorySection(entries: book.reads)
                    .padding(.horizontal)
                socialSection
                actionsSection
            }
            .padding(.bottom, 32)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProgressEditor) {
            ProgressEditor(book: book)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    generateShareCard()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share book card")
            }
        }
        .sheet(isPresented: $showDNFSheet) {
            dnfSheet
        }
        .sheet(isPresented: $showShareCardSheet) {
            ActivityView(activityItems: shareCardItems, applicationActivities: nil)
        }
        .sheet(isPresented: $showRecommendSheet) {
            ActivityView(activityItems: [recommendText], applicationActivities: nil)
        }
        .sheet(isPresented: $showAddToListSheet) {
            addToListSheet
        }
        .alert("Delete Book", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                repository.deleteBook(book)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to remove \"\(book.title)\" from your library? This cannot be undone.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            CoverImage(coverID: book.coverImageID, size: .large, accessibilityTitle: book.title)
                .frame(width: 200, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 4)
                .padding(.top, 16)

            Text(book.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(book.authorName)
                .font(.title3)
                .foregroundStyle(.secondary)

            if let year = book.firstPublishYear {
                Text(String(year))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - User Section

    private var userSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Shelf badge
                Label(book.shelf.displayName, systemImage: book.shelf.systemImage)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(shelfColor.opacity(0.15))
                    .foregroundStyle(shelfColor)
                    .clipShape(Capsule())
                    .accessibilityLabel("Shelf: \(book.shelf.displayName)")

                Spacer()

                // Favourite toggle
                Button {
                    if reduceMotion {
                        book.isFavourite.toggle()
                        try? modelContext.save()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            book.isFavourite.toggle()
                            try? modelContext.save()
                        }
                    }
                } label: {
                    Image(systemName: book.isFavourite ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(book.isFavourite ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: book.isFavourite)
                .accessibilityLabel(book.isFavourite ? "Remove from favourites" : "Add to favourites")
            }
            .padding(.horizontal)

            // Rating
            RatingPicker(rating: ratingBinding, mode: .interactive)
        }
    }

    private var ratingBinding: Binding<Double?> {
        Binding(
            get: { book.userRating },
            set: { newValue in
                repository.updateRating(book, rating: newValue)
            }
        )
    }

    private var shelfColor: Color {
        switch book.shelf {
        case .wantToRead: .blue
        case .reading: .green
        case .read: .gray
        case .dnf: .orange
        }
    }

    // MARK: - Progress Section

    @ViewBuilder
    private var progressSection: some View {
        if book.shelf == .reading {
            VStack(spacing: 8) {
                if let currentPage = book.currentPage {
                    if let pageCount = book.pageCount, pageCount > 0 {
                        let progress = min(Double(currentPage) / Double(pageCount), 1.0)
                        let percentage = Int(progress * 100)

                        ProgressView(value: progress)
                            .tint(.green)
                            .padding(.horizontal)
                            .accessibilityLabel("Reading progress: \(percentage) percent")

                        Text("Page \(currentPage) of \(pageCount) (\(percentage)%)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Page \(currentPage)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showProgressEditor = true
                } label: {
                    Label("Update Progress", systemImage: "book.pages")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Synopsis Section

    @ViewBuilder
    private var synopsisSection: some View {
        if let synopsis = book.synopsis, !synopsis.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Synopsis")
                    .font(.headline)

                Text(synopsis)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(synopsisExpanded ? nil : 3)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        synopsisExpanded.toggle()
                    }
                } label: {
                    Text(synopsisExpanded ? "Show Less" : "Show More")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: 8) {
                if let pageCount = book.pageCount {
                    detailItem(label: "Pages", value: "\(pageCount)")
                }
                if let publisher = book.publisher {
                    detailItem(label: "Publisher", value: publisher)
                }
                if let language = book.language {
                    detailItem(label: "Language", value: language)
                }
                if let year = book.firstPublishYear {
                    detailItem(label: "First Published", value: String(year))
                }
            }

            if !book.subjects.isEmpty {
                subjectTags
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private func detailItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline)
        }
    }

    private var subjectTags: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(book.subjects.prefix(10)), id: \.self) { subject in
                Text(subject)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            // Re-read / Try Again
            if book.shelf == .read {
                Button {
                    startReread()
                } label: {
                    Label("Read Again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }

            if book.shelf == .dnf {
                Button {
                    startReread()
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)

                // Show DNF info
                dnfInfoSection
            }

            // DNF option for currently reading
            if book.shelf == .reading {
                Button {
                    dnfPage = ""
                    dnfReason = ""
                    showDNFSheet = true
                } label: {
                    Label("Did Not Finish", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .padding(.horizontal)
            }

            // Move to shelf
            Button {
                showShelfPicker = true
            } label: {
                Label("Move to Shelf", systemImage: "arrow.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .confirmationDialog("Move to Shelf", isPresented: $showShelfPicker) {
                ForEach(Shelf.allCases.filter { $0 != book.shelf }, id: \.self) { shelf in
                    Button(shelf.displayName) {
                        handleShelfMove(to: shelf)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }

            // Delete
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Remove from Library", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
    }

    // MARK: - DNF Info

    @ViewBuilder
    private var dnfInfoSection: some View {
        let latestDNF = book.reads
            .filter { $0.dnfPage != nil || $0.dnfReason != nil }
            .sorted { ($0.finishDate ?? $0.startDate ?? .distantPast) > ($1.finishDate ?? $1.startDate ?? .distantPast) }
            .first

        if let dnf = latestDNF {
            VStack(alignment: .leading, spacing: 4) {
                if let page = dnf.dnfPage {
                    Text("Stopped at page \(page)")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                if let reason = dnf.dnfReason, !reason.isEmpty {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
    }

    // MARK: - DNF Sheet

    private var dnfSheet: some View {
        NavigationStack {
            Form {
                Section("Page stopped at (optional)") {
                    TextField("Page number", text: $dnfPage)
                        .keyboardType(.numberPad)
                }
                Section("Reason (optional)") {
                    TextField("Why did you stop?", text: $dnfReason, axis: .vertical)
                        .lineLimit(3...6)

                    // Suggestion chips
                    FlowLayout(spacing: 6) {
                        ForEach(dnfSuggestions, id: \.self) { suggestion in
                            Button {
                                dnfReason = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(dnfReason == suggestion ? Color.orange.opacity(0.2) : Color(.systemGray5))
                                    .foregroundStyle(dnfReason == suggestion ? .orange : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Did Not Finish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDNFSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        performDNF()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var dnfSuggestions: [String] {
        ["Lost interest", "Too slow", "Not for me", "Will try again later"]
    }

    // MARK: - Social Section

    private var socialSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            Button {
                generateShareCard()
            } label: {
                Label("Share Book Card", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button {
                generateRecommendation()
            } label: {
                Label("Recommend to a Friend", systemImage: "person.wave.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            Button {
                showAddToListSheet = true
            } label: {
                Label("Add to Reading List", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
        }
    }

    // MARK: - Add to List Sheet

    private var addToListSheet: some View {
        NavigationStack {
            AddBookToListSheet(book: book, readingLists: readingLists)
                .navigationTitle("Add to List")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showAddToListSheet = false
                        }
                    }
                }
        }
    }

    // MARK: - Share Card Generation

    private func generateShareCard() {
        Task {
            var coverImage: UIImage?
            if let coverID = book.coverImageID {
                coverImage = await repository.imageCache.image(for: coverID, size: .large)
            }
            let image = ShareCardRenderer.renderImage(for: book, coverImage: coverImage)
            if let image {
                shareCardItems = [image]
                showShareCardSheet = true
            }
        }
    }

    // MARK: - Recommendation Generation

    private func generateRecommendation() {
        var message = "I think you'd enjoy \"\(book.title)\" by \(book.authorName)"

        if let rating = book.userRating {
            let ratingText: String
            if rating == floor(rating) {
                ratingText = String(format: "%.0f", rating)
            } else {
                ratingText = String(format: "%.1f", rating)
            }
            message += "\nI rated it \u{2B50} \(ratingText)/5"
        }

        message += "\n\nFind it on Open Library: https://openlibrary.org\(book.olWorkKey)"

        recommendText = message
        showRecommendSheet = true
    }

    // MARK: - Actions

    private func startReread() {
        // Snapshot the current rating onto the most recent ReadEntry if it has none
        if let currentRating = book.userRating {
            let latestEntry = book.reads
                .sorted { ($0.finishDate ?? $0.startDate ?? .distantPast) > ($1.finishDate ?? $1.startDate ?? .distantPast) }
                .first
            if let entry = latestEntry, entry.rating == nil {
                entry.rating = currentRating
            }
        }

        book.dateStarted = .now
        book.dateFinished = nil
        book.currentPage = nil
        repository.updateShelf(book, to: .reading)
    }

    private func performDNF() {
        let entry = ReadEntry(
            book: book,
            startDate: book.dateStarted,
            finishDate: .now,
            dnfPage: Int(dnfPage),
            dnfReason: dnfReason.isEmpty ? nil : dnfReason
        )
        modelContext.insert(entry)
        repository.updateShelf(book, to: .dnf)
        try? modelContext.save()
        showDNFSheet = false
    }

    private func handleShelfMove(to shelf: Shelf) {
        switch shelf {
        case .read:
            // Create a ReadEntry when marking as read
            let entry = ReadEntry(
                book: book,
                startDate: book.dateStarted,
                finishDate: .now
            )
            modelContext.insert(entry)
            repository.updateShelf(book, to: .read)
            try? modelContext.save()
        case .dnf:
            dnfPage = ""
            dnfReason = ""
            showDNFSheet = true
        default:
            repository.updateShelf(book, to: shelf)
        }
    }
}

// MARK: - Add Book to List Sheet

struct AddBookToListSheet: View {
    let book: Book
    let readingLists: [ReadingList]

    @Environment(\.modelContext) private var modelContext
    @State private var showNewListAlert = false
    @State private var newListName = ""

    var body: some View {
        Group {
            if readingLists.isEmpty {
                ContentUnavailableView {
                    Label("No Lists", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Create a reading list first.")
                } actions: {
                    Button("Create a List") {
                        newListName = ""
                        showNewListAlert = true
                    }
                }
            } else {
                List {
                    Section {
                        ForEach(readingLists) { list in
                            Button {
                                toggleBookInList(list)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(list.name)
                                            .font(.headline)
                                        Text("\(list.bookKeys.count) \(list.bookKeys.count == 1 ? "book" : "books")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if list.bookKeys.contains(book.olWorkKey) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                    }

                    Section {
                        Button {
                            newListName = ""
                            showNewListAlert = true
                        } label: {
                            Label("New List", systemImage: "plus")
                        }
                    }
                }
            }
        }
        .alert("New Reading List", isPresented: $showNewListAlert) {
            TextField("List name", text: $newListName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                createListAndAdd()
            }
        } message: {
            Text("Enter a name for your new reading list.")
        }
    }

    private func toggleBookInList(_ list: ReadingList) {
        if list.bookKeys.contains(book.olWorkKey) {
            list.bookKeys.removeAll { $0 == book.olWorkKey }
        } else {
            list.bookKeys.append(book.olWorkKey)
        }
        try? modelContext.save()
    }

    private func createListAndAdd() {
        let trimmed = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let list = ReadingList(name: trimmed, bookKeys: [book.olWorkKey])
        modelContext.insert(list)
        try? modelContext.save()
    }
}

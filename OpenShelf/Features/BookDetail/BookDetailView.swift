import SwiftUI
import SwiftData
import ActivityKit

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
    @State private var showFinishCelebration = false

    // Collapsible section state (#114)
    @State private var isDetailsExpanded = true
    @State private var isSubjectsExpanded = false
    @State private var isReadHistoryExpanded = false
    @State private var isActionsExpanded = true

    // Expandable subject tags state (#126)
    @State private var showAllSubjects = false

    // DNF state
    @State private var dnfPage: String = ""
    @State private var dnfReason: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Social/sharing state
    @State private var showShareCardSheet = false
    @State private var showRecommendSheet = false
    @State private var recommendText: String = ""
    @State private var showAddToListSheet = false
    @State private var coverImageForShare: UIImage?

    // Up Next prompt state
    @State private var showUpNextPrompt = false
    @State private var upNextBook: Book?

    // Privacy state
    @State private var showPrivacyConfirmation = false

    // Series editing state
    @State private var editingSeriesName: String = ""
    @State private var editingSeriesPosition: String = ""

    // Author search state
    @State private var authorBooks: [SearchResult] = []
    @State private var isLoadingAuthorBooks = false

    // Followed author state
    @Query private var followedAuthors: [FollowedAuthor]

    // Library availability
    @AppStorage("preferredLibraryService") private var preferredLibraryService: String = LibraryService.libby.rawValue
    @AppStorage("customLibraryURLTemplate") private var customLibraryURLTemplate: String = ""
    @AppStorage("spydusCloudSlug") private var spydusCloudSlug: String = ""
    @AppStorage("kohaLibraryDomain") private var kohaLibraryDomain: String = ""

    // Library availability check state
    @State private var availabilityStatus: LibraryAvailabilityChecker.AvailabilityStatus = .unknown

    // Author page state
    @State private var showAuthorPage = false

    // Reading session (Live Activity)
    @State private var readingSessionActivity: Activity<ReadingSessionAttributes>?

    @ScaledMetric(relativeTo: .body) private var coverWidth: CGFloat = 200
    @ScaledMetric(relativeTo: .body) private var coverHeight: CGFloat = 300
    @ScaledMetric(relativeTo: .caption) private var thumbWidth: CGFloat = 80
    @ScaledMetric(relativeTo: .caption) private var thumbHeight: CGFloat = 120

    @Query(sort: \ReadingList.dateCreated, order: .reverse) private var readingLists: [ReadingList]
    @Query private var allLibraryBooks: [Book]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                userSection
                progressSection
                synopsisSection
                collapsibleDetailsSection
                NotesEditor(book: book)
                    .padding(.horizontal)
                collapsibleReadHistorySection
                similarBooksSection
                moreByAuthorSection
                libraryAvailabilitySection
                BuyLinksSection(isbn: book.isbn13 ?? book.isbn10)
                if !book.isPrivate {
                    socialSection
                }
                collapsibleActionsSection
            }
            .padding(.bottom, 32)
        }
        .overlay {
            CelebrationOverlay(isPresented: $showFinishCelebration)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProgressEditor) {
            ProgressEditor(book: book)
        }
        .toolbar {
            if !book.isPrivate {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            if let coverID = book.coverImageID {
                                coverImageForShare = await repository.imageCache.image(for: coverID, size: .large)
                            }
                            showShareCardSheet = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share book card")
                }
            }
        }
        .sheet(isPresented: $showDNFSheet) {
            dnfSheet
        }
        .sheet(isPresented: $showFinishedRating) {
            finishedRatingSheet
        }
        .sheet(isPresented: $showShareCardSheet) {
            ShareCardSheet(book: book, coverImage: coverImageForShare)
        }
        .sheet(isPresented: $showRecommendSheet) {
            ActivityView(activityItems: [recommendText], applicationActivities: nil)
        }
        .sheet(isPresented: $showAddToListSheet) {
            addToListSheet
        }
        .sheet(isPresented: $showAuthorPage) {
            AuthorPageView(
                authorName: book.authorName,
                authorKey: nil,
                authorBooks: authorBooks
            )
            .environment(repository)
        }
        .sheet(isPresented: $showSeriesEditor) {
            seriesEditorSheet
        }
        .alert("Start reading \(upNextBook?.title ?? "")?", isPresented: $showUpNextPrompt) {
            Button("Start Reading") {
                if let nextBook = upNextBook {
                    repository.updateShelf(nextBook, to: .reading)
                }
            }
            Button("Not Now", role: .cancel) {}
        }
        .onAppear {
            restoreReadingSession()
        }
        .task {
            await loadAuthorBooks()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            CoverImage(coverID: book.coverImageID, size: .large, accessibilityTitle: book.title)
                .frame(width: coverWidth, height: coverHeight)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .shadow(radius: 4)
                .padding(.top, 16)

            Text(book.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showAuthorPage = true
            } label: {
                HStack(spacing: 4) {
                    Text(book.authorName)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View author page for \(book.authorName)")

            if let narrator = book.narrator, !narrator.isEmpty {
                Text("Narrated by \(narrator)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if book.format == .audiobook, let durationMinutes = book.durationMinutes, durationMinutes > 0 {
                let hours = durationMinutes / 60
                let minutes = durationMinutes % 60
                Text(hours > 0 && minutes > 0 ? "\(hours)h \(minutes)m" : hours > 0 ? "\(hours)h" : "\(minutes)m")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            if let year = book.firstPublishYear {
                Text(String(year))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }

            followAuthorButton
        }
    }

    // MARK: - Follow Author

    private var isFollowingAuthor: Bool {
        followedAuthors.contains { $0.authorName == book.authorName }
    }

    private var followAuthorButton: some View {
        Button {
            toggleFollowAuthor()
        } label: {
            Label(
                isFollowingAuthor ? "Following" : "Follow Author",
                systemImage: isFollowingAuthor ? "checkmark.circle.fill" : "person.badge.plus"
            )
            .font(.subheadline)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isFollowingAuthor ? Color.accentColor.opacity(0.15) : Color(.systemGray5))
            .foregroundStyle(isFollowingAuthor ? Color.accentColor : Color.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isFollowingAuthor)
        .accessibilityLabel(isFollowingAuthor ? "Unfollow \(book.authorName)" : "Follow \(book.authorName)")
    }

    private func toggleFollowAuthor() {
        if let existing = followedAuthors.first(where: { $0.authorName == book.authorName }) {
            modelContext.delete(existing)
        } else {
            let followed = FollowedAuthor(authorName: book.authorName)
            modelContext.insert(followed)
        }
        try? modelContext.save()
    }

    // MARK: - User Section

    private var userSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Shelf badge — tappable to change shelf
                Menu {
                    ForEach(Shelf.allCases.filter { $0 != book.shelf }, id: \.self) { shelf in
                        Button {
                            handleShelfMove(to: shelf)
                        } label: {
                            Label(shelf.displayName, systemImage: shelf.systemImage)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Label(book.shelf.displayName, systemImage: book.shelf.systemImage)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(shelfColor.opacity(0.15))
                    .foregroundStyle(shelfColor)
                    .clipShape(Capsule())
                }
                .accessibilityLabel("Shelf: \(book.shelf.displayName)")
                .accessibilityHint("Tap to change shelf")

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
                let latest = (book.reads ?? [])
                    .sorted { ($0.finishDate ?? $0.startDate ?? .distantPast) > ($1.finishDate ?? $1.startDate ?? .distantPast) }
                    .first
                latest?.rating = newValue
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

    private var isAudiobook: Bool {
        book.format == .audiobook
    }

    @ViewBuilder
    private var progressSection: some View {
        if book.shelf == .reading {
            VStack(spacing: 8) {
                if isAudiobook {
                    audiobookProgressDisplay
                    readingPaceEstimate
                } else if let currentPage = book.currentPage {
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
                    readingPaceEstimate
                }

                HStack(spacing: 12) {
                    Button {
                        showProgressEditor = true
                    } label: {
                        Label(
                            isAudiobook ? "Update Listening Progress" : "Update Progress",
                            systemImage: isAudiobook ? "headphones" : "book.pages"
                        )
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    if readingSessionActivity != nil {
                        Button {
                            stopReadingSession()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else if ActivityAuthorizationInfo().areActivitiesEnabled {
                        Button {
                            startReadingSession()
                        } label: {
                            Label(
                                isAudiobook ? "Start Listening" : "Start Reading",
                                systemImage: "play.fill"
                            )
                            .font(.subheadline)
                            .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var audiobookProgressDisplay: some View {
        if let currentChapter = book.currentChapter, let chapterCount = book.chapterCount, chapterCount > 0 {
            let progress = min(Double(currentChapter) / Double(chapterCount), 1.0)
            let percentage = Int(progress * 100)

            ProgressView(value: progress)
                .tint(.green)
                .padding(.horizontal)
                .accessibilityLabel("Listening progress: \(percentage) percent")

            HStack(spacing: 4) {
                Image(systemName: "headphones")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                Text("Chapter \(currentChapter) of \(chapterCount) (\(percentage)%)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else if let currentChapter = book.currentChapter {
            HStack(spacing: 4) {
                Image(systemName: "headphones")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                Text("Chapter \(currentChapter)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 4) {
                Image(systemName: "headphones")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
                Text("Listening")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Reading Pace Estimate (#121)

    @ViewBuilder
    private var readingPaceEstimate: some View {
        if isAudiobook {
            if let currentChapter = book.currentChapter,
               let chapterCount = book.chapterCount, chapterCount > 0,
               let dateStarted = book.dateStarted {
                let daysSinceStarted = max(Calendar.current.dateComponents([.day], from: dateStarted, to: .now).day ?? 0, 0)
                if daysSinceStarted >= 1, currentChapter > 0 {
                    let chaptersPerDay = Double(currentChapter) / Double(daysSinceStarted)
                    let chaptersLeft = chapterCount - currentChapter
                    if chaptersPerDay > 0, chaptersLeft > 0 {
                        let daysLeft = Int(ceil(Double(chaptersLeft) / chaptersPerDay))
                        if daysLeft > 365 {
                            Text("Take your time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("At your pace, ~\(daysLeft) days left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } else {
            if let currentPage = book.currentPage,
               let pageCount = book.pageCount, pageCount > 0,
               let dateStarted = book.dateStarted {
                let daysSinceStarted = max(Calendar.current.dateComponents([.day], from: dateStarted, to: .now).day ?? 0, 0)
                if daysSinceStarted >= 1, currentPage > 0 {
                    let pagesPerDay = Double(currentPage) / Double(daysSinceStarted)
                    let pagesLeft = pageCount - currentPage
                    if pagesPerDay > 0, pagesLeft > 0 {
                        let daysLeft = Int(ceil(Double(pagesLeft) / pagesPerDay))
                        if daysLeft > 365 {
                            Text("Take your time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("At your pace, ~\(daysLeft) days left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reading Session

    private func startReadingSession() {
        let attributes = ReadingSessionAttributes(
            olWorkKey: book.olWorkKey,
            bookTitle: book.isPrivate ? (isAudiobook ? "Listening" : "Reading") : book.title,
            authorName: book.isPrivate ? "" : book.authorName,
            pageCount: book.pageCount,
            isAudiobook: isAudiobook,
            chapterCount: book.chapterCount
        )
        let state = ReadingSessionAttributes.ContentState(
            currentPage: book.currentPage ?? 0,
            startedAt: .now,
            currentChapter: book.currentChapter
        )
        do {
            readingSessionActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            // Live Activities not available
        }
    }

    private func stopReadingSession() {
        guard let activity = readingSessionActivity else { return }
        let activityID = activity.id
        let currentPage = book.currentPage ?? 0
        let startedAt = activity.content.state.startedAt
        readingSessionActivity = nil
        Task {
            let state = ReadingSessionAttributes.ContentState(
                currentPage: currentPage,
                startedAt: startedAt,
                currentChapter: book.currentChapter
            )
            let content = ActivityContent(state: state, staleDate: nil)
            for liveActivity in Activity<ReadingSessionAttributes>.activities where liveActivity.id == activityID {
                await liveActivity.end(content, dismissalPolicy: .immediate)
            }
        }
    }

    private func restoreReadingSession() {
        guard readingSessionActivity == nil else { return }
        let workKey = book.olWorkKey
        readingSessionActivity = Activity<ReadingSessionAttributes>.activities.first {
            $0.attributes.olWorkKey == workKey
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

    // MARK: - Collapsible Details Section (#114)

    private var collapsibleDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup(isExpanded: $isDetailsExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    detailsGrid

                    // Format picker
                    HStack {
                        Text("Format")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Picker("Format", selection: Binding(
                            get: { book.format },
                            set: { newValue in
                                book.format = newValue
                                try? modelContext.save()
                            }
                        )) {
                            ForEach(BookFormat.allCases, id: \.self) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("Details")
                    .font(.headline)
            }

            // Series section (always visible)
            seriesSection

            // Collapsible subjects (#114 + #126)
            if !book.subjects.isEmpty {
                DisclosureGroup(isExpanded: $isSubjectsExpanded) {
                    subjectTags
                        .padding(.top, 8)
                } label: {
                    Text("Subjects (\(book.subjects.count))")
                        .font(.headline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    // MARK: - Details Grid

    private var detailsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], alignment: .leading, spacing: 8) {
            if let pageCount = book.pageCount {
                HStack(spacing: 4) {
                    detailItem(label: "Pages", value: "\(pageCount)")
                    if book.format != .book {
                        Text(book.format.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
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
    }

    // MARK: - Series Section (#125 — larger touch targets)

    @ViewBuilder
    private var seriesSection: some View {
        if let seriesName = book.seriesName, !seriesName.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Series")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        HStack(spacing: 4) {
                            Text(seriesName)
                                .font(.subheadline)
                            if let position = book.seriesPosition {
                                Text("#\(position)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        editingSeriesName = book.seriesName ?? ""
                        editingSeriesPosition = book.seriesPosition.map { String($0) } ?? ""
                        showSeriesEditor = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.title3)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Edit series information")

                    Button(role: .destructive) {
                        book.seriesName = nil
                        book.seriesPosition = nil
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Remove series information")
                }
            }
        } else {
            Button {
                editingSeriesName = ""
                editingSeriesPosition = ""
                showSeriesEditor = true
            } label: {
                Label("Add to Series", systemImage: "books.vertical")
                    .font(.subheadline)
            }
        }
    }

    @State private var showSeriesEditor = false

    private var seriesEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Series Name") {
                    TextField("e.g. The Lord of the Rings", text: $editingSeriesName)
                        .accessibilityLabel("Series name")
                }
                Section("Volume Number") {
                    TextField("e.g. 1", text: $editingSeriesPosition)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Volume number")
                }
            }
            .navigationTitle("Series")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSeriesEdits()
                        showSeriesEditor = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showSeriesEditor = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveSeriesEdits() {
        let trimmedName = editingSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            book.seriesName = nil
            book.seriesPosition = nil
        } else {
            book.seriesName = trimmedName
            book.seriesPosition = Int(editingSeriesPosition).map { max(1, $0) }
        }
        try? modelContext.save()
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

    // MARK: - Subject Tags (#126 — expandable)

    private var subjectTags: some View {
        let displayLimit = 8
        let subjects = book.subjects
        let shouldTruncate = subjects.count > displayLimit
        let visibleSubjects = showAllSubjects ? subjects : Array(subjects.prefix(displayLimit))
        let remainingCount = subjects.count - displayLimit

        return FlowLayout(spacing: 6) {
            ForEach(visibleSubjects, id: \.self) { subject in
                Text(subject)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }

            if shouldTruncate {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showAllSubjects.toggle()
                    }
                } label: {
                    Text(showAllSubjects ? "Show less" : "+\(remainingCount) more")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Collapsible Read History (#114)

    @ViewBuilder
    private var collapsibleReadHistorySection: some View {
        if !(book.reads ?? []).isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup(isExpanded: $isReadHistoryExpanded) {
                    ReadHistorySection(entries: book.reads ?? [], book: book, showHeader: false)
                        .padding(.top, 8)
                } label: {
                    Text("Reading History")
                        .font(.headline)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Collapsible Actions (#114)

    private var collapsibleActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            DisclosureGroup(isExpanded: $isActionsExpanded) {
                actionsContent
                    .padding(.top, 8)
            } label: {
                Text("Actions")
                    .font(.headline)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Similar Books Section

    @ViewBuilder
    private var similarBooksSection: some View {
        if allLibraryBooks.count >= 5 {
            let similar = RecommendationEngine.similarBooks(to: book, from: allLibraryBooks, limit: 5)
            if !similar.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.horizontal)

                    Text("You might also like")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(similar) { rec in
                                NavigationLink {
                                    BookDetailView(book: rec)
                                } label: {
                                    VStack(spacing: 6) {
                                        CoverImage(coverID: rec.coverImageID, size: .small)
                                            .frame(width: thumbWidth, height: thumbHeight)
                                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                                        Text(rec.title)
                                            .font(.caption)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: thumbWidth)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // MARK: - More by Author Section

    @ViewBuilder
    private var moreByAuthorSection: some View {
        if !authorBooks.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.horizontal)

                Text("More by \(book.authorName)")
                    .font(.headline)
                    .padding(.horizontal)

                if isLoadingAuthorBooks {
                    ProgressView()
                        .padding(.horizontal)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(authorBooks) { result in
                                NavigationLink {
                                    authorBookDestination(result)
                                } label: {
                                    VStack(spacing: 6) {
                                        CoverImage(coverID: result.coverI, size: .small)
                                            .frame(width: thumbWidth, height: thumbHeight)
                                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                                        Text(result.title)
                                            .font(.caption)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: thumbWidth)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func authorBookDestination(_ result: SearchResult) -> some View {
        if let existingBook = allLibraryBooks.first(where: { $0.olWorkKey == result.key }) {
            BookDetailView(book: existingBook)
        } else {
            SearchResultDetailView(searchResult: result)
        }
    }

    // MARK: - Library Availability Section

    @ViewBuilder
    private var libraryAvailabilitySection: some View {
        let isbn = book.isbn13 ?? book.isbn10
        if let isbn {
            VStack(spacing: 12) {
                Divider()
                    .padding(.horizontal)

                Button {
                    openLibraryLink(isbn: isbn)
                } label: {
                    HStack {
                        Label("Check library availability", systemImage: "building.columns")
                        if availabilityStatus == .likelyAvailable {
                            Text("Likely available")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        } else if availabilityStatus == .checking {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
            }
            .task(id: isbn) {
                await checkLibraryAvailability(isbn: isbn)
            }
        }
    }

    private func openLibraryLink(isbn: String) {
        let service = LibraryService(rawValue: preferredLibraryService) ?? .libby
        let url: URL?

        switch service {
        case .custom:
            url = LibraryService.customURL(template: customLibraryURLTemplate, isbn: isbn)
        case .spydusCloud:
            url = LibraryService.spydusCloudURL(slug: spydusCloudSlug, isbn: isbn)
        case .koha:
            url = LibraryService.kohaURL(domain: kohaLibraryDomain, isbn: isbn)
        default:
            url = service.url(for: isbn)
        }

        if let url {
            UIApplication.shared.open(url)
        }
    }

    private func checkLibraryAvailability(isbn: String) async {
        let service = LibraryService(rawValue: preferredLibraryService) ?? .libby
        guard service == .spydusCloud, !spydusCloudSlug.isEmpty else { return }

        // Check cache first
        let cached = LibraryAvailabilityChecker.shared.cachedStatus(for: isbn)
        if cached != .unknown {
            availabilityStatus = cached
            return
        }

        availabilityStatus = .checking
        availabilityStatus = await LibraryAvailabilityChecker.shared.check(isbn: isbn, slug: spydusCloudSlug)
    }

    // MARK: - Actions Content

    private var actionsContent: some View {
        VStack(spacing: 12) {
            // Re-read / Try Again
            if book.shelf == .read {
                Button {
                    startReread()
                } label: {
                    Label("Read Again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if book.shelf == .dnf {
                Button {
                    startReread()
                } label: {
                    Label("Try Again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // Show DNF info
                dnfInfoSection
            }

            if book.shelf == .reading {
                Button {
                    finishedRating = nil
                    showFinishedRating = true
                } label: {
                    Label(
                        isAudiobook ? "Finished Listening" : "Finished Reading",
                        systemImage: "checkmark.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
                .accessibilityHint(isAudiobook
                    ? "Marks this audiobook as finished and prompts for a rating"
                    : "Marks this book as finished and prompts for a rating"
                )

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
            }

            // Move to shelf
            Button {
                showShelfPicker = true
            } label: {
                Label("Move to Shelf", systemImage: "arrow.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .confirmationDialog("Move to Shelf", isPresented: $showShelfPicker) {
                ForEach(Shelf.allCases.filter { $0 != book.shelf }, id: \.self) { shelf in
                    Button(shelf.displayName) {
                        handleShelfMove(to: shelf)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }

            // Make Private / Make Visible
            Button {
                showPrivacyConfirmation = true
            } label: {
                Label(
                    book.isPrivate ? "Make Visible" : "Make Private",
                    systemImage: book.isPrivate ? "eye" : "eye.slash"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .confirmationDialog(
                "Private Book",
                isPresented: $showPrivacyConfirmation,
                titleVisibility: .visible
            ) {
                Button(book.isPrivate ? "Make Visible" : "Make Private") {
                    book.isPrivate.toggle()
                    try? modelContext.save()
                    SpotlightIndexer.indexBook(book)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Private books are hidden from stats, widgets, and shared content.")
            }

            // Delete
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Remove from Library", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
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
    }

    // MARK: - DNF Info

    @ViewBuilder
    private var dnfInfoSection: some View {
        let latestDNF = (book.reads ?? [])
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
        }
    }

    // MARK: - DNF Sheet

    private var dnfSheet: some View {
        NavigationStack {
            Form {
                Section("Page stopped at (optional)") {
                    TextField("Page number", text: $dnfPage)
                        .keyboardType(.numberPad)
                        .accessibilityLabel("Page stopped at")
                }
                Section("Reason (optional)") {
                    TextField("Why did you stop?", text: $dnfReason, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Reason for not finishing")

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
                Task {
                    if let coverID = book.coverImageID {
                        coverImageForShare = await repository.imageCache.image(for: coverID, size: .large)
                    }
                    showShareCardSheet = true
                }
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
            let latestEntry = (book.reads ?? [])
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
        promptUpNextIfAvailable()
    }

    private func promptUpNextIfAvailable() {
        if let nextBook = repository.nextInQueue() {
            upNextBook = nextBook
            showUpNextPrompt = true
        }
    }

    private func loadAuthorBooks() async {
        guard !book.authorName.isEmpty else { return }
        isLoadingAuthorBooks = true
        defer { isLoadingAuthorBooks = false }

        do {
            let results = try await repository.searchByAuthor(name: book.authorName)
            // Filter out the current book and limit
            authorBooks = results
                .filter { $0.key != book.olWorkKey }
                .prefix(5)
                .map { $0 }
        } catch {
            // Non-critical — silently fail
            authorBooks = []
        }
    }

    private var finishedRatingSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(isAudiobook ? "Rate This Audiobook" : "Rate This Book")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(isAudiobook ? "How would you rate this audiobook?" : "How would you rate this book?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                RatingPicker(rating: $finishedRating, mode: .interactive)

                Spacer()
            }
            .padding()
            .navigationTitle(isAudiobook ? "Rate This Audiobook" : "Rate This Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        finishReading(rating: nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Rating") {
                        finishReading(rating: finishedRating)
                    }
                    .disabled(finishedRating == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func finishReading(rating: Double?) {
        guard book.shelf == .reading else { return }
        if let pageCount = book.pageCount {
            repository.updateProgress(book, page: pageCount)
        }
        let entry = ReadEntry(
            book: book,
            startDate: book.dateStarted,
            finishDate: .now,
            rating: rating
        )
        modelContext.insert(entry)
        repository.updateShelf(book, to: .read)
        if let rating {
            repository.updateRating(book, rating: rating)
        }
        try? modelContext.save()
        showFinishedRating = false
        showFinishCelebration = true
        promptUpNextIfAvailable()
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
            promptUpNextIfAvailable()
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
                .accessibilityLabel("New list name")
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

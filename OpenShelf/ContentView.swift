import SwiftUI
import SwiftData
import CoreSpotlight

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Environment(BookRepository.self) private var repository

    @Query private var activityEvents: [ActivityEvent]
    @AppStorage("lastViewedActivityTimestamp") private var lastViewedActivityTimestamp: Double = 0

    @State private var selectedTab = "Library"
    @State private var deepLinkBookKey: String?
    @State private var showDeepLinkBook = false
    @State private var deepLinkBook: Book?
    @State private var deepLinkSearchResult: SearchResult?
    @State private var isLoadingDeepLink = false
    @State private var deepLinkSearchQuery: String?
    @State private var showFollowedToast = false
    @State private var followedDisplayName = ""

    init() {
        let cutoff = Date.now.addingTimeInterval(-30 * 24 * 60 * 60)
        _activityEvents = Query(
            filter: #Predicate<ActivityEvent> { $0.timestamp > cutoff },
            sort: \.timestamp,
            order: .reverse
        )
    }

    private var unseenActivityCount: Int {
        guard lastViewedActivityTimestamp > 0 else { return 0 }
        let threshold = Date(timeIntervalSinceReferenceDate: lastViewedActivityTimestamp)
        return min(activityEvents.filter { $0.timestamp > threshold }.count, 99)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Library", systemImage: "books.vertical", value: "Library") {
                LibraryView()
            }

            Tab("Discover", systemImage: "sparkle.magnifyingglass", value: "Discover") {
                SearchView(prefillQuery: $deepLinkSearchQuery)
            }

            Tab("Following", systemImage: "person.2", value: "Following") {
                FollowingView()
            }
            .badge(unseenActivityCount)

            Tab("Stats", systemImage: "chart.bar", value: "Stats") {
                StatsView()
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { newValue in hasCompletedOnboarding = !newValue }
        )) {
            OnboardingView()
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            handleSpotlightActivity(activity)
        }
        .sheet(isPresented: $showDeepLinkBook) {
            deepLinkSheet
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchOpenLibrary)) { notification in
            if let query = notification.userInfo?["query"] as? String, !query.isEmpty {
                deepLinkSearchQuery = query
                selectedTab = "Discover"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .publicShelfFollowed)) { notification in
            handleFollowedShelfNotification(notification)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == "Following" {
                lastViewedActivityTimestamp = Date.now.timeIntervalSinceReferenceDate
            }
        }
        .toast(isPresented: $showFollowedToast, message: "You're now following \(followedDisplayName)!", icon: "person.badge.plus")
    }

    // MARK: - Follow Handling

    private func handleFollowedShelfNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let ownerRecordName = info["ownerRecordName"] as? String,
              let displayName = info["displayName"] as? String,
              let snapshotData = info["snapshotData"] as? Data else { return }

        let owner = ownerRecordName
        let descriptor = FetchDescriptor<FollowedShelf>(
            predicate: #Predicate { $0.ownerRecordName == owner }
        )

        let isNew: Bool
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            existing.cachedSnapshot = snapshotData
            existing.displayName = displayName
            existing.lastFetched = .now
            isNew = false
        } else {
            let shelf = FollowedShelf(
                ownerRecordName: ownerRecordName,
                displayName: displayName,
                cachedSnapshot: snapshotData
            )
            modelContext.insert(shelf)
            isNew = true
        }
        try? modelContext.save()
        selectedTab = "Following"
        if isNew {
            followedDisplayName = displayName
            showFollowedToast = true
        }
    }

    // MARK: - Spotlight Handling

    private func handleSpotlightActivity(_ activity: NSUserActivity) {
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }

        if identifier.hasPrefix("/works/") {
            let key = identifier
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate { $0.olWorkKey == key }
            )
            if let book = (try? modelContext.fetch(descriptor))?.first {
                deepLinkBook = book
                showDeepLinkBook = true
            }
        }
    }

    // MARK: - Deep Link Handling

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "openshelf" else { return }

        // Handle openshelf://stats
        if url.host == "stats" {
            selectedTab = "Stats"
            return
        }

        // Handle openshelf://discover or openshelf://search?q={query}
        if url.host == "discover" || url.host == "search" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let query = components?.queryItems?.first(where: { $0.name == "q" })?.value, !query.isEmpty {
                deepLinkSearchQuery = query
            }
            selectedTab = "Discover"
            return
        }

        // Handle openshelf://book?isbn={isbn}
        if url.host == "book" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            if let isbn = components?.queryItems?.first(where: { $0.name == "isbn" })?.value, !isbn.isEmpty {
                handleISBNDeepLink(isbn)
                return
            }
        }

        // Handle openshelf://book/{olWorkKey}
        guard url.host == "book" else { return }

        // The work key path: e.g. openshelf://book/works/OL12345W -> /works/OL12345W
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard !pathComponents.isEmpty else { return }

        let workKey = "/works/" + pathComponents.joined(separator: "/")
        deepLinkBookKey = workKey

        // Check if book exists in library
        let key = workKey
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate { $0.olWorkKey == key }
        )

        if let existingBook = (try? modelContext.fetch(descriptor))?.first {
            deepLinkBook = existingBook
            showDeepLinkBook = true
        } else {
            // Search Open Library for this work key
            isLoadingDeepLink = true
            showDeepLinkBook = true
            Task {
                do {
                    let detail = try await repository.fetchDetail(for: workKey)
                    let searchResult = SearchResult(
                        key: workKey,
                        title: detail.title,
                        authorName: nil,
                        firstPublishYear: nil,
                        numberOfPagesMedian: nil,
                        coverI: detail.primaryCoverID,
                        editionCount: nil,
                        isbn: nil,
                        subject: detail.subjects,
                        idGoodreads: nil,
                        ratingsAverage: nil,
                        ratingsCount: nil,
                        readinglogCount: nil,
                        wantToReadCount: nil,
                        currentlyReadingCount: nil,
                        alreadyReadCount: nil,
                        language: nil
                    )
                    deepLinkSearchResult = searchResult
                } catch {
                    // If fetch fails, just dismiss
                }
                isLoadingDeepLink = false
            }
        }
    }

    private func handleISBNDeepLink(_ isbn: String) {
        // Check if a book with this ISBN already exists
        let descriptor13 = FetchDescriptor<Book>(
            predicate: #Predicate { $0.isbn13 == isbn }
        )
        let descriptor10 = FetchDescriptor<Book>(
            predicate: #Predicate { $0.isbn10 == isbn }
        )

        if let existing = (try? modelContext.fetch(descriptor13))?.first
            ?? (try? modelContext.fetch(descriptor10))?.first {
            deepLinkBook = existing
            showDeepLinkBook = true
            return
        }

        // Not in library — open search with the ISBN
        deepLinkSearchQuery = isbn
        selectedTab = "Discover"
    }

    @ViewBuilder
    private var deepLinkSheet: some View {
        if let book = deepLinkBook {
            NavigationStack {
                BookDetailView(book: book)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showDeepLinkBook = false
                                deepLinkBook = nil
                            }
                        }
                    }
            }
        } else if let result = deepLinkSearchResult {
            // BookDetailSheet provides its own NavigationStack
            BookDetailSheet(searchResult: result) {
                showDeepLinkBook = false
                deepLinkSearchResult = nil
            }
        } else if isLoadingDeepLink {
            NavigationStack {
                ProgressView("Loading book...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            NavigationStack {
                ContentUnavailableView {
                    Label("Book Not Found", systemImage: "book.closed")
                } description: {
                    Text("This book could not be found.")
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            showDeepLinkBook = false
                        }
                    }
                }
            }
        }
    }
}

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Query(sort: \ReadingGoal.year, order: .reverse) private var goals: [ReadingGoal]
    @Query private var books: [Book]
    @Query private var readingDays: [ReadingDay]
    @Query(sort: \FollowedAuthor.dateFollowed, order: .reverse) private var followedAuthors: [FollowedAuthor]
    @Query(sort: \DismissedBook.dateDismissed, order: .reverse) private var dismissedBooks: [DismissedBook]

    @Environment(BookRepository.self) private var repository

    @State private var showImportView = false
    @State private var showExportView = false
    @State private var showSetGoal = false
    @State private var showLibraryPicker = false
    @State private var cacheSize: Int64?
    @State private var showClearCacheAlert = false
    @State private var showCacheClearedToast = false

    @AppStorage("preferredLibraryService") private var preferredLibraryService: String = LibraryService.libby.rawValue
    @AppStorage("customLibraryURLTemplate") private var customLibraryURLTemplate: String = ""
    @AppStorage("spydusCloudSlug") private var spydusCloudSlug: String = ""
    @AppStorage("kohaLibraryDomain") private var kohaLibraryDomain: String = ""
    @AppStorage("streakReminderEnabled") private var streakReminderEnabled: Bool = false
    @AppStorage("preferredBookshop") private var preferredBookshop: String = BookshopPreference.bookshopOrg.rawValue
    @AppStorage("preferredAudiobook") private var preferredAudiobook: String = AudiobookPreference.libroFm.rawValue
    @AppStorage("preferredLanguages") private var preferredLanguagesJSON: String = "[\"eng\"]"

    @State private var showLanguagePicker = false

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        NavigationStack {
            List {
                readingGoalSection
                SocialSettingsSection()
                preferredLanguagesSection
                notificationsSection
                privacySection
                followedAuthorsSection
                dismissedBooksSection
                bookshopsSection
                librarySection
                importSection
                exportSection
                storageSection
                pastUnwrappedSection
                goalHistorySection
                aboutSection
                TipJarSection()
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showImportView) {
                ImportView()
            }
            .sheet(isPresented: $showExportView) {
                ExportView()
            }
            .sheet(isPresented: $showSetGoal) {
                SetReadingGoalSheet(
                    year: currentYear,
                    existingGoal: goals.first { $0.year == currentYear }
                )
            }
            .sheet(isPresented: $showLibraryPicker) {
                LibraryPickerView()
            }
            .sheet(isPresented: $showLanguagePicker) {
                LanguagePickerSheet(preferredLanguagesJSON: $preferredLanguagesJSON)
            }
            .toast(isPresented: $showCacheClearedToast, message: "Cache cleared")
        }
    }

    // MARK: - Reading Goal Section

    private var readingGoalSection: some View {
        Section("Reading Goal") {
            if let goal = goals.first(where: { $0.year == currentYear }) {
                let booksRead = StatsCalculator.booksRead(
                    from: books,
                    filter: .year(currentYear)
                ).count

                HStack {
                    VStack(alignment: .leading) {
                        Text("\(String(currentYear)) Goal")
                        Text("\(booksRead) of \(goal.target) books")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") {
                        showSetGoal = true
                    }
                }
            } else {
                Button {
                    showSetGoal = true
                } label: {
                    Label("Set Reading Goal for \(String(currentYear))", systemImage: "target")
                }
            }
        }
    }

    // MARK: - Notifications Section

    @Environment(\.modelContext) private var modelContext

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Streak reminder", isOn: $streakReminderEnabled)
                .onChange(of: streakReminderEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission()
                    } else {
                        cancelStreakReminder()
                    }
                }

            if streakReminderEnabled {
                Text("Reminds you at 8pm if you haven't opened the app and have a streak over 3 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func requestNotificationPermission() {
        let centre = UNUserNotificationCenter.current()
        centre.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                if granted {
                    scheduleStreakReminder()
                } else {
                    streakReminderEnabled = false
                }
            }
        }
    }

    private func scheduleStreakReminder() {
        let streak = StatsCalculator.currentStreak(from: readingDays)
        guard streak > 3 else { return }

        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: ["streakReminder"])

        let content = UNMutableNotificationContent()
        content.title = "Don't break your streak!"
        content.body = "You're on a \(streak)-day reading streak. Open a book to keep it going."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "streakReminder",
            content: content,
            trigger: trigger
        )

        centre.add(request)
    }

    private func cancelStreakReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["streakReminder"]
        )
    }

    // MARK: - Privacy Section

    @AppStorage("includePrivateBooksInStats") private var includePrivateBooksInStats: Bool = false

    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Include private books in stats", isOn: $includePrivateBooksInStats)

            Text("When enabled, private books are included in your reading stats and Books Unwrapped. They are never included in shared content.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Preferred Languages Section

    private var selectedLanguageCodes: [String] {
        guard let data = preferredLanguagesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return ["eng"]
        }
        return decoded
    }

    private func removeLanguage(_ code: String) {
        var codes = selectedLanguageCodes
        codes.removeAll { $0 == code }
        if codes.isEmpty { codes = ["eng"] }
        if let data = try? JSONEncoder().encode(codes),
           let json = String(data: data, encoding: .utf8) {
            preferredLanguagesJSON = json
        }
    }

    private var preferredLanguagesSection: some View {
        Section {
            ForEach(selectedLanguageCodes, id: \.self) { code in
                HStack {
                    Text(LanguageCode.displayName(for: code))
                    Spacer()
                    if selectedLanguageCodes.count > 1 {
                        Button {
                            removeLanguage(code)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(LanguageCode.displayName(for: code))")
                    }
                }
            }

            Button {
                showLanguagePicker = true
            } label: {
                Label("Add Language", systemImage: "plus.circle")
            }
        } header: {
            Text("Discover Languages")
        } footer: {
            Text("Discover recommendations show books in these languages. Search results are not filtered.")
        }
    }

    // MARK: - Followed Authors Section

    @ViewBuilder
    private var followedAuthorsSection: some View {
        if !followedAuthors.isEmpty {
            Section("Followed Authors") {
                ForEach(Array(followedAuthors.enumerated()), id: \.element.id) { index, author in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(author.authorName)
                                .font(.body)
                            if let lastChecked = author.lastCheckedDate {
                                Text("Last checked: \(lastChecked, format: .dateTime.month().day())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Not yet checked")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text("Following")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            modelContext.delete(author)
                            try? modelContext.save()
                        } label: {
                            Label("Unfollow", systemImage: "trash")
                        }
                    }
                    .accessibilityAction(named: "Unfollow") {
                        modelContext.delete(author)
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    // MARK: - Not Interested Section

    @ViewBuilder
    private var dismissedBooksSection: some View {
        if !dismissedBooks.isEmpty {
            Section("Not Interested") {
                ForEach(dismissedBooks) { dismissed in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dismissed.title)
                                .font(.body)
                            Text(dismissed.author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(dismissed.dateDismissed, format: .dateTime.day().month().year())
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            modelContext.delete(dismissed)
                            try? modelContext.save()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                        .accessibilityLabel("Undo dismissal of \(dismissed.title)")
                    }
                    .accessibilityAction(named: "Undo dismissal") {
                        modelContext.delete(dismissed)
                        try? modelContext.save()
                    }
                }
            }
        }
    }

    // MARK: - Bookshops Section

    private var selectedBookshopPreference: Binding<BookshopPreference> {
        Binding(
            get: { BookshopPreference(rawValue: preferredBookshop) ?? .bookshopOrg },
            set: { preferredBookshop = $0.rawValue }
        )
    }

    private var selectedAudiobookPreference: Binding<AudiobookPreference> {
        Binding(
            get: { AudiobookPreference(rawValue: preferredAudiobook) ?? .libroFm },
            set: { preferredAudiobook = $0.rawValue }
        )
    }

    private var bookshopsSection: some View {
        Section("Bookshops") {
            Picker("Preferred bookshop", selection: selectedBookshopPreference) {
                ForEach(BookshopPreference.allCases, id: \.self) { pref in
                    Text(pref.rawValue).tag(pref)
                }
            }

            Picker("Audiobook service", selection: selectedAudiobookPreference) {
                ForEach(AudiobookPreference.allCases, id: \.self) { pref in
                    Text(pref.rawValue).tag(pref)
                }
            }

            Text("Open Shelf uses affiliate links for Bookshop.org, Hive, and Libro.fm. This helps fund development and supports independent bookshops. Your purchase data is never tracked by us.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Library Section

    private var selectedLibraryService: Binding<LibraryService> {
        Binding(
            get: { LibraryService(rawValue: preferredLibraryService) ?? .libby },
            set: { preferredLibraryService = $0.rawValue }
        )
    }

    private var librarySection: some View {
        Section("Library") {
            Button {
                showLibraryPicker = true
            } label: {
                Label("Find your library", systemImage: "building.columns.fill")
            }

            Picker("Preferred library service", selection: selectedLibraryService) {
                ForEach(LibraryService.allCases) { service in
                    Text(service.rawValue).tag(service)
                }
            }

            if selectedLibraryService.wrappedValue == .spydusCloud {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Council slug", text: $spydusCloudSlug)
                        .accessibilityLabel("Spydus Cloud council slug")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Your council's identifier, e.g. manchester, birmingham")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if selectedLibraryService.wrappedValue == .koha {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Catalogue domain", text: $kohaLibraryDomain)
                        .accessibilityLabel("Koha library catalogue domain")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Your library's Koha catalogue domain, e.g. catalogue.mylibrary.org")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if selectedLibraryService.wrappedValue == .custom {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("URL template", text: $customLibraryURLTemplate)
                        .accessibilityLabel("Custom library URL template")
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Text("Use {isbn} as a placeholder. e.g. https://example.com/search?q={isbn}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Import Section

    private var importSection: some View {
        Section("Import") {
            Button {
                showImportView = true
            } label: {
                Label("Import from Goodreads", systemImage: "square.and.arrow.down")
            }
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section("Export") {
            Button {
                showExportView = true
            } label: {
                Label("Export Library", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section("Storage") {
            HStack {
                Text("Cache size")
                Spacer()
                if let size = cacheSize {
                    Text(formattedCacheSize(size))
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .task { await computeCacheSize() }

            Button(role: .destructive) {
                showClearCacheAlert = true
            } label: {
                Label("Clear Cache", systemImage: "trash")
            }
            .disabled(cacheSize == nil || cacheSize == 0)
            .alert("Clear Cache?", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    Task { await clearAllCaches() }
                }
            } message: {
                Text("This will remove cached book covers and metadata. They will be re-downloaded as needed.")
            }
        }
    }

    private func computeCacheSize() async {
        let coverSize = await repository.imageCache.cacheSize()
        let metaSize = await repository.metadataCache.cacheSize()
        cacheSize = coverSize + metaSize
    }

    private func clearAllCaches() async {
        await repository.imageCache.clearCache()
        await repository.metadataCache.clearCache()
        await computeCacheSize()
        showCacheClearedToast = true
    }

    private func formattedCacheSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Past Unwrapped Section

    private var pastUnwrappedYears: [Int] {
        let yearCounts = Dictionary(
            grouping: books.filter { $0.shelf == .read && $0.dateFinished != nil },
            by: { Calendar.current.component(.year, from: $0.dateFinished!) }
        )
        return yearCounts.filter { $0.value.count >= 5 }.keys.sorted(by: >)
    }

    @ViewBuilder
    private var pastUnwrappedSection: some View {
        if !pastUnwrappedYears.isEmpty {
            Section("Unwrapped") {
                NavigationLink {
                    PastUnwrappedListView(availableYears: pastUnwrappedYears)
                } label: {
                    Label("View past Unwrapped", systemImage: "gift.fill")
                }
            }
        }
    }

    // MARK: - Goal History Section

    @ViewBuilder
    private var goalHistorySection: some View {
        let pastGoals = goals.filter { $0.year != currentYear }
        if !pastGoals.isEmpty {
            Section("Goal History") {
                ForEach(pastGoals, id: \.year) { goal in
                    let booksRead = StatsCalculator.booksRead(
                        from: books,
                        filter: .year(goal.year)
                    ).count

                    HStack {
                        Text(String(goal.year))
                        Spacer()
                        Text("\(booksRead) of \(goal.target)")
                            .foregroundStyle(.secondary)
                        if booksRead >= goal.target {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .accessibilityLabel("Goal achieved")
                        }
                    }
                }
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                HStack(spacing: 4) {
                    Text("1.0")
                        .foregroundStyle(.secondary)
                    if UserDefaults.standard.bool(forKey: "hasTipped") {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }

            HStack {
                Text("Privacy")
                Spacer()
                Text("Data syncs via iCloud when signed in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

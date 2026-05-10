import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Query(sort: \ReadingGoal.year, order: .reverse) private var goals: [ReadingGoal]
    @Query private var books: [Book]
    @Query(sort: \FollowedAuthor.dateFollowed, order: .reverse) private var followedAuthors: [FollowedAuthor]

    @State private var showImportView = false
    @State private var showExportView = false
    @State private var showSetGoal = false
    @State private var showLibraryPicker = false

    @AppStorage("preferredLibraryService") private var preferredLibraryService: String = LibraryService.libby.rawValue
    @AppStorage("customLibraryURLTemplate") private var customLibraryURLTemplate: String = ""
    @AppStorage("spydusCloudSlug") private var spydusCloudSlug: String = ""
    @AppStorage("kohaLibraryDomain") private var kohaLibraryDomain: String = ""
    @AppStorage("streakReminderEnabled") private var streakReminderEnabled: Bool = false
    @AppStorage("preferredBookshop") private var preferredBookshop: String = BookshopPreference.bookshopOrg.rawValue
    @AppStorage("preferredAudiobook") private var preferredAudiobook: String = AudiobookPreference.libroFm.rawValue

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        NavigationStack {
            List {
                readingGoalSection
                notificationsSection
                privacySection
                followedAuthorsSection
                bookshopsSection
                librarySection
                importSection
                exportSection
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
            if granted {
                scheduleStreakReminder()
            } else {
                Task { @MainActor in
                    streakReminderEnabled = false
                }
            }
        }
    }

    private func scheduleStreakReminder() {
        let streak = StatsCalculator.currentStreak(from: books)
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

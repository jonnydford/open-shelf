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

    @AppStorage("preferredLibraryService") private var preferredLibraryService: String = LibraryService.libby.rawValue
    @AppStorage("customLibraryURLTemplate") private var customLibraryURLTemplate: String = ""
    @AppStorage("streakReminderEnabled") private var streakReminderEnabled: Bool = false

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        NavigationStack {
            List {
                readingGoalSection
                notificationsSection
                followedAuthorsSection
                librarySection
                importSection
                exportSection
                pastUnwrappedSection
                goalHistorySection
                aboutSection
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
                }
            }
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
            Picker("Preferred library service", selection: selectedLibraryService) {
                ForEach(LibraryService.allCases) { service in
                    Text(service.rawValue).tag(service)
                }
            }

            if selectedLibraryService.wrappedValue == .custom {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("URL template", text: $customLibraryURLTemplate)
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
                Text("1.0")
                    .foregroundStyle(.secondary)
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

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(sort: \ReadingGoal.year, order: .reverse) private var goals: [ReadingGoal]
    @Query private var books: [Book]

    @State private var showImportView = false
    @State private var showSetGoal = false

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    var body: some View {
        NavigationStack {
            List {
                readingGoalSection
                importSection
                goalHistorySection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showImportView) {
                ImportView()
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
                Text("All data stays on your device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

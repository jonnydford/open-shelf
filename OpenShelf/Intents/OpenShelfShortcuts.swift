import AppIntents

struct OpenShelfShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: UpdateReadingProgressIntent(),
            phrases: [
                "Log my reading in \(.applicationName)",
                "Update my reading progress in \(.applicationName)",
                "Log pages in \(.applicationName)"
            ],
            shortTitle: "Log Reading",
            systemImageName: "book.pages"
        )

        AppShortcut(
            intent: GetReadingStatsIntent(),
            phrases: [
                "How's my reading going in \(.applicationName)",
                "Get my reading stats from \(.applicationName)",
                "How many books have I read in \(.applicationName)"
            ],
            shortTitle: "Reading Stats",
            systemImageName: "chart.bar"
        )

        AppShortcut(
            intent: GetCurrentlyReadingIntent(),
            phrases: [
                "What am I reading in \(.applicationName)",
                "Show my current books in \(.applicationName)",
                "What books am I reading in \(.applicationName)"
            ],
            shortTitle: "Currently Reading",
            systemImageName: "book.fill"
        )

        AppShortcut(
            intent: LogFinishedBookIntent(),
            phrases: [
                "I finished my book in \(.applicationName)",
                "Mark my book as finished in \(.applicationName)",
                "I finished reading in \(.applicationName)"
            ],
            shortTitle: "Finish Book",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: GetCurrentStreakIntent(),
            phrases: [
                "What's my reading streak in \(.applicationName)",
                "How long have I been reading in \(.applicationName)"
            ],
            shortTitle: "Reading Streak",
            systemImageName: "flame"
        )
    }
}

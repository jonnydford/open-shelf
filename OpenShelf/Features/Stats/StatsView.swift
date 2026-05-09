import SwiftUI
import SwiftData

struct StatsView: View {
    @Query private var books: [Book]

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Stats Coming Soon",
                systemImage: "chart.bar",
                description: Text("Reading statistics will appear here once you start tracking books.")
            )
            .navigationTitle("Stats")
        }
    }
}

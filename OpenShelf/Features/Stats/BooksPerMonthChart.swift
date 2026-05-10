import SwiftUI
import SwiftData
import Charts

struct BooksPerMonthChart: View {
    let books: [Book]
    let filter: YearFilter

    @State private var selectedMonthName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Books Per Month")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            chartContent
                .frame(height: 200)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Books Per Month chart")
        .accessibilityValue(chartAccessibilityValue)
    }

    private var chartAccessibilityValue: String {
        switch filter {
        case .year:
            let data = StatsCalculator.booksPerMonth(books)
            let nonZero = data.filter { $0.count > 0 }
            if nonZero.isEmpty { return "No books read" }
            let parts = nonZero.map { "\($0.monthName): \($0.count)" }
            return parts.joined(separator: ", ")
        case .allTime:
            let total = books.count
            return "\(total) books read across all years"
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        switch filter {
        case .year:
            monthlyChart
        case .allTime:
            yearlyChart
        }
    }

    private var monthlyChart: some View {
        let data = StatsCalculator.booksPerMonth(books)
        let currentMonth = Calendar.current.component(.month, from: .now)

        return Chart(data) { item in
            BarMark(
                x: .value("Month", item.monthName),
                y: .value("Books", item.count)
            )
            .foregroundStyle(item.month == currentMonth ? Color.accentColor : Color.accentColor.opacity(0.6))
            .cornerRadius(4)

            if let selected = selectedMonthName, selected == item.monthName {
                RuleMark(x: .value("Month", item.monthName))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top) {
                        Text("\(item.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                    }
            }
        }
        .chartXSelection(value: $selectedMonthName)
        .chartYAxisLabel("Books")
        .animation(.easeInOut, value: data.map(\.count))
        .accessibilityHint("Tap a bar to see count for that month")
    }

    private var yearlyChart: some View {
        let data = StatsCalculator.booksPerYear(books)

        return Chart(data) { item in
            BarMark(
                x: .value("Year", String(item.year)),
                y: .value("Books", item.count)
            )
            .foregroundStyle(Color.accentColor)
            .cornerRadius(4)
        }
        .chartYAxisLabel("Books")
        .animation(.easeInOut, value: data.map(\.count))
    }
}

struct BooksPerMonthDetailView: View {
    @Query private var books: [Book]
    @State private var filter: YearFilter = .year(Calendar.current.component(.year, from: .now))

    private var availableYears: [Int] {
        let years = Set(books.compactMap { $0.dateFinished.map { Calendar.current.component(.year, from: $0) } })
        return years.sorted(by: >)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                yearPicker
                BooksPerMonthChart(
                    books: filteredBooks,
                    filter: filter
                )
                .padding(.horizontal)
            }
        }
        .navigationTitle("Books Per Month")
    }

    private var filteredBooks: [Book] {
        StatsCalculator.booksRead(from: books, filter: filter)
    }

    private var yearPicker: some View {
        Picker("Period", selection: $filter) {
            Text("All Time").tag(YearFilter.allTime)
            ForEach(availableYears, id: \.self) { year in
                Text(String(year)).tag(YearFilter.year(year))
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

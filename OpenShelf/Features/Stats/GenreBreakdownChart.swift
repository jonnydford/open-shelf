import SwiftUI
import SwiftData
import Charts

struct GenreBreakdownChart: View {
    let books: [Book]

    @State private var selectedGenre: String?

    private var genres: [StatsCalculator.GenreCount] {
        StatsCalculator.genreBreakdown(books)
    }

    private var total: Int {
        genres.reduce(0) { $0 + $1.count }
    }

    private static let genreColours: [Color] = [
        .blue, .orange, .green, .purple, .pink, .cyan, .yellow
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Genre Breakdown")
                .font(.headline)

            if genres.isEmpty {
                ContentUnavailableView("No genre data", systemImage: "tag")
                    .frame(height: 200)
            } else {
                donutChart
                    .frame(height: 220)

                legend
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Genre Breakdown chart")
        .accessibilityValue(genreAccessibilityValue)
    }

    private var genreAccessibilityValue: String {
        if genres.isEmpty { return "No genre data" }
        let parts = genres.map { "\($0.genre): \($0.count) book\($0.count == 1 ? "" : "s") (\(percentage($0.count)))" }
        return parts.joined(separator: ", ")
    }

    private var donutChart: some View {
        Chart(genres) { item in
            SectorMark(
                angle: .value("Count", item.count),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("Genre", item.genre))
            .cornerRadius(4)
            .opacity(selectedGenre == nil || selectedGenre == item.genre ? 1 : 0.4)
        }
        .chartForegroundStyleScale(
            domain: genres.map(\.genre),
            range: Self.genreColours.prefix(genres.count).map { $0 }
        )
        .chartLegend(.hidden)
        .chartAngleSelection(value: Binding(
            get: { selectedAngleValue },
            set: { newValue in
                guard let newValue else {
                    selectedGenre = nil
                    return
                }
                selectedGenre = genreForAngle(newValue)
            }
        ))
        .chartBackground { _ in
            if let selected = selectedGenre, let genre = genres.first(where: { $0.genre == selected }) {
                VStack(spacing: 2) {
                    Text(genre.genre)
                        .font(.caption.bold())
                    Text("\(genre.count)")
                        .font(.title2.bold())
                    Text(percentage(genre.count))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
            ForEach(Array(genres.enumerated()), id: \.element.id) { index, genre in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Self.genreColours[index % Self.genreColours.count])
                        .frame(width: 10, height: 10)
                    Text(genre.genre)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                    Text("\(genre.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .onTapGesture {
                    withAnimation {
                        selectedGenre = selectedGenre == genre.genre ? nil : genre.genre
                    }
                }
            }
        }
    }

    private func percentage(_ count: Int) -> String {
        guard total > 0 else { return "0%" }
        let pct = Double(count) / Double(total) * 100
        return String(format: "%.0f%%", pct)
    }

    private var selectedAngleValue: Int? {
        guard let selected = selectedGenre else { return nil }
        var cumulative = 0
        for genre in genres {
            cumulative += genre.count
            if genre.genre == selected {
                return cumulative - genre.count / 2
            }
        }
        return nil
    }

    private func genreForAngle(_ angle: Int) -> String? {
        var cumulative = 0
        for genre in genres {
            cumulative += genre.count
            if angle < cumulative {
                return genre.genre
            }
        }
        return genres.last?.genre
    }
}

struct GenreBreakdownDetailView: View {
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
                GenreBreakdownChart(books: filteredBooks)
                    .padding(.horizontal)
            }
        }
        .navigationTitle("Genre Breakdown")
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

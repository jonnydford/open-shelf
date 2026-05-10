import SwiftUI
import Charts

struct UnwrappedShareSheet: View {
    let year: Int
    let booksReadCount: Int
    let totalPages: Int
    let estimatedHours: Int
    let topBook: Book?
    let topGenre: (genre: String, count: Int, percentage: String)?
    let favouriteAuthor: String?
    let longestStreak: Int
    let goalTarget: Int?
    let goalMet: Bool
    let averageDays: Int?
    let fastestRead: (title: String, days: Int)?
    let longestRead: (title: String, days: Int)?
    let monthlyData: [StatsCalculator.MonthCount]

    enum ShareMode: String, CaseIterable {
        case summary = "Summary"
        case allCards = "All Cards"
    }

    @AppStorage("preferredShareFormat") private var preferredFormat: String = ShareFormat.story.rawValue
    @State private var selectedFormat: ShareFormat = .story
    @State private var shareMode: ShareMode = .summary
    @State private var showActivitySheet = false
    @State private var shareItems: [Any] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()

                if shareMode == .summary {
                    summaryCardView
                        .scaleEffect(previewScale)
                        .frame(width: previewWidth, height: previewHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 8)
                } else {
                    allCardsCarousel
                }

                Spacer()

                Picker("Mode", selection: $shareMode) {
                    ForEach(ShareMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ShareFormatPicker(selectedFormat: $selectedFormat)
                    .padding(.horizontal)

                Button {
                    renderAndShare()
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
            }
            .padding(.vertical)
            .navigationTitle("Share Your Year")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedFormat = ShareFormat(rawValue: preferredFormat) ?? .story
            }
            .onChange(of: selectedFormat) { _, newValue in
                preferredFormat = newValue.rawValue
            }
            .sheet(isPresented: $showActivitySheet) {
                ActivityView(activityItems: shareItems, applicationActivities: nil)
            }
        }
    }

    // MARK: - All Cards Carousel

    private var allCardsCarousel: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(0..<10, id: \.self) { index in
                    cardView(at: index)
                        .scaleEffect(carouselScale)
                        .frame(width: carouselWidth, height: carouselHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
        }
        .scrollTargetBehavior(.viewAligned)
        .frame(height: carouselHeight + 16)
    }

    @ViewBuilder
    private func cardView(at index: Int) -> some View {
        let dims = selectedFormat.dimensions
        Group {
            switch index {
            case 0: openerCardContent
            case 1: totalStatsCardContent
            case 2: topBookCardContent
            case 3: topGenreCardContent
            case 4: favouriteAuthorCardContent
            case 5: readingPaceCardContent
            case 6: monthlyBreakdownCardContent
            case 7: streakCardContent
            case 8: goalProgressCardContent
            default: closerCardContent
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 18))
                Text("Open Shelf")
                    .font(.system(size: 20, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.4))
            .padding(.bottom, 48)
        }
        .frame(width: dims.width, height: dims.height)
    }

    // MARK: - Individual Card Content

    private var openerCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: cardIconSize))
                    .foregroundStyle(Color.accentColor)
                Text("Your \(String(year))\nin Books")
                    .font(.system(size: cardTitleSize, weight: .bold))
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
    }

    private var totalStatsCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 8) {
                    Text("\(booksReadCount)")
                        .font(.system(size: cardBigNumberSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                    Text("books read")
                        .font(.system(size: cardLabelSize))
                }
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(totalPages.formatted())")
                            .font(.system(size: statNumberSize, weight: .bold))
                        Text("pages")
                            .font(.system(size: statLabelSize))
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        Text("~\(estimatedHours)")
                            .font(.system(size: statNumberSize, weight: .bold))
                        Text("hours")
                            .font(.system(size: statLabelSize))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    private var topBookCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()
                Text("Top Rated")
                    .font(.system(size: statLabelSize))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
                if let book = topBook {
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: cardIconSize))
                            .foregroundStyle(.yellow)
                        Text(book.title)
                            .font(.system(size: statNumberSize + 8, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text(book.authorName)
                            .font(.system(size: statNumberSize))
                            .foregroundStyle(.secondary)
                        if let rating = book.userRating {
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                                        .foregroundStyle(.yellow)
                                }
                            }
                            .font(.system(size: statNumberSize))
                        }
                    }
                } else {
                    Text("No rated books")
                        .font(.system(size: statNumberSize))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 48)
        }
    }

    private var topGenreCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()
                Text("Top Genre")
                    .font(.system(size: statLabelSize))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
                if let genre = topGenre {
                    VStack(spacing: 12) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: cardIconSize))
                            .foregroundStyle(Color.accentColor)
                        Text(genre.genre)
                            .font(.system(size: cardTitleSize, weight: .bold))
                        Text("\(genre.count) books \u{00B7} \(genre.percentage)")
                            .font(.system(size: statNumberSize))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No genre data")
                        .font(.system(size: statNumberSize))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var favouriteAuthorCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()
                Text("Favourite Author")
                    .font(.system(size: statLabelSize))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
                if let author = favouriteAuthor {
                    VStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.system(size: cardIconSize))
                            .foregroundStyle(Color.accentColor)
                        Text(author)
                            .font(.system(size: cardTitleSize, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("No author data")
                        .font(.system(size: statNumberSize))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 48)
        }
    }

    private var readingPaceCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 32) {
                Spacer()
                Text("Reading Pace")
                    .font(.system(size: statLabelSize))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
                if let avg = averageDays {
                    VStack(spacing: 8) {
                        Text("\(avg)")
                            .font(.system(size: cardBigNumberSize, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                        Text("days per book on average")
                            .font(.system(size: cardLabelSize))
                    }
                }
                HStack(spacing: 32) {
                    if let fastest = fastestRead {
                        VStack(spacing: 4) {
                            Text("\(fastest.days)d")
                                .font(.system(size: statNumberSize, weight: .bold))
                                .foregroundStyle(.green)
                            Text("fastest")
                                .font(.system(size: statLabelSize))
                                .foregroundStyle(.secondary)
                            Text(fastest.title)
                                .font(.system(size: statLabelSize - 2))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    if let longest = longestRead {
                        VStack(spacing: 4) {
                            Text("\(longest.days)d")
                                .font(.system(size: statNumberSize, weight: .bold))
                                .foregroundStyle(.orange)
                            Text("longest")
                                .font(.system(size: statLabelSize))
                                .foregroundStyle(.secondary)
                            Text(longest.title)
                                .font(.system(size: statLabelSize - 2))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 48)
        }
    }

    private var monthlyBreakdownCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()
                Text("Monthly Breakdown")
                    .font(.system(size: statLabelSize))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
                Chart(monthlyData) { item in
                    BarMark(
                        x: .value("Month", item.monthName),
                        y: .value("Books", item.count)
                    )
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
                }
                .chartYAxisLabel("Books")
                .frame(height: chartHeight)
                .padding(.horizontal, 48)
                Spacer()
            }
        }
    }

    private var streakCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()
                Text("Longest Streak")
                    .font(.system(size: statLabelSize))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: cardIconSize))
                        .foregroundStyle(.orange)
                    Text("\(longestStreak)")
                        .font(.system(size: cardBigNumberSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("consecutive days reading")
                        .font(.system(size: cardLabelSize))
                }
                Spacer()
            }
        }
    }

    private var goalProgressCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()
                Text("Reading Goal")
                    .font(.system(size: statLabelSize))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)
                if let target = goalTarget {
                    VStack(spacing: 12) {
                        Image(systemName: goalMet ? "trophy.fill" : "target")
                            .font(.system(size: cardIconSize))
                            .foregroundStyle(goalMet ? Color.yellow : Color.accentColor)
                        Text("\(booksReadCount) of \(target)")
                            .font(.system(size: cardBigNumberSize * 0.7, weight: .bold, design: .rounded))
                        Text(goalMet ? "Goal reached!" : "books towards your goal")
                            .font(.system(size: cardLabelSize))
                            .foregroundStyle(goalMet ? .green : .secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "target")
                            .font(.system(size: cardIconSize))
                            .foregroundStyle(.secondary)
                        Text("No goal set for \(String(year))")
                            .font(.system(size: statNumberSize))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    private var closerCardContent: some View {
        UnwrappedCard {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: cardIconSize))
                    .foregroundStyle(Color.accentColor)
                Text("See you in\n\(String(year + 1))")
                    .font(.system(size: cardTitleSize, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Keep turning those pages.")
                    .font(.system(size: cardLabelSize))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCardView: some View {
        let dims = selectedFormat.dimensions
        return UnwrappedCard {
            VStack(spacing: summarySpacing) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: headerIconSize))
                        .foregroundStyle(Color.accentColor)

                    Text("My \(String(year)) in Books")
                        .font(.system(size: headerFontSize, weight: .bold))
                }

                VStack(spacing: 4) {
                    Text("\(booksReadCount)")
                        .font(.system(size: bigNumberSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                    Text("books read")
                        .font(.system(size: labelSize))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(totalPages.formatted())")
                            .font(.system(size: statNumberSize, weight: .bold))
                        Text("pages")
                            .font(.system(size: statLabelSize))
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        Text("~\(estimatedHours)")
                            .font(.system(size: statNumberSize, weight: .bold))
                        Text("hours")
                            .font(.system(size: statLabelSize))
                            .foregroundStyle(.secondary)
                    }
                }

                if let book = topBook {
                    VStack(spacing: 4) {
                        Text("Top Rated")
                            .font(.system(size: statLabelSize))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        Text(book.title)
                            .font(.system(size: statNumberSize, weight: .semibold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text(book.authorName)
                            .font(.system(size: statLabelSize))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 32)
                }

                if let genre = topGenre {
                    VStack(spacing: 4) {
                        Text("Top Genre")
                            .font(.system(size: statLabelSize))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(1)
                        Text(genre.genre)
                            .font(.system(size: statNumberSize, weight: .semibold))
                        Text("\(genre.count) books \u{00B7} \(genre.percentage)")
                            .font(.system(size: statLabelSize))
                            .foregroundStyle(.secondary)
                    }
                }

                if selectedFormat != .square {
                    if let author = favouriteAuthor {
                        VStack(spacing: 4) {
                            Text("Favourite Author")
                                .font(.system(size: statLabelSize))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(1)
                            Text(author)
                                .font(.system(size: statNumberSize, weight: .semibold))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 32)
                    }

                    if longestStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: statNumberSize))
                                .foregroundStyle(.orange)
                            Text("\(longestStreak) day streak")
                                .font(.system(size: statNumberSize, weight: .semibold))
                        }
                    }
                }

                if let target = goalTarget {
                    HStack(spacing: 4) {
                        Image(systemName: goalMet ? "trophy.fill" : "target")
                            .font(.system(size: statNumberSize))
                            .foregroundStyle(goalMet ? .yellow : Color.accentColor)
                        Text("\(booksReadCount)/\(target) goal")
                            .font(.system(size: statNumberSize, weight: .semibold))
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 18))
                    Text("Open Shelf")
                        .font(.system(size: 20, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 48)
        }
        .frame(width: dims.width, height: dims.height)
    }

    // MARK: - Summary Sizing

    private var summarySpacing: CGFloat {
        switch selectedFormat {
        case .story: return 28
        case .portrait: return 20
        case .square: return 16
        }
    }

    private var headerIconSize: CGFloat {
        selectedFormat == .square ? 36 : 48
    }

    private var headerFontSize: CGFloat {
        selectedFormat == .square ? 32 : 40
    }

    private var bigNumberSize: CGFloat {
        selectedFormat == .square ? 56 : 72
    }

    private var labelSize: CGFloat {
        selectedFormat == .square ? 20 : 24
    }

    private var statNumberSize: CGFloat {
        selectedFormat == .square ? 20 : 24
    }

    private var statLabelSize: CGFloat {
        selectedFormat == .square ? 14 : 16
    }

    // MARK: - Individual Card Sizing

    private var cardIconSize: CGFloat {
        selectedFormat == .square ? 48 : 64
    }

    private var cardTitleSize: CGFloat {
        selectedFormat == .square ? 40 : 56
    }

    private var cardBigNumberSize: CGFloat {
        selectedFormat == .square ? 72 : 96
    }

    private var cardLabelSize: CGFloat {
        selectedFormat == .square ? 22 : 28
    }

    private var chartHeight: CGFloat {
        switch selectedFormat {
        case .story: return 400
        case .portrait: return 300
        case .square: return 200
        }
    }

    // MARK: - Preview Dimensions

    private var previewScale: CGFloat {
        300.0 / selectedFormat.dimensions.width
    }

    private var previewWidth: CGFloat {
        selectedFormat.dimensions.width * previewScale
    }

    private var previewHeight: CGFloat {
        selectedFormat.dimensions.height * previewScale
    }

    // MARK: - Carousel Dimensions

    private var carouselScale: CGFloat {
        180.0 / selectedFormat.dimensions.width
    }

    private var carouselWidth: CGFloat {
        selectedFormat.dimensions.width * carouselScale
    }

    private var carouselHeight: CGFloat {
        selectedFormat.dimensions.height * carouselScale
    }

    // MARK: - Share

    private func renderAndShare() {
        switch shareMode {
        case .summary:
            let renderer = ImageRenderer(content: summaryCardView)
            renderer.scale = 2.0
            guard let image = renderer.uiImage else { return }
            shareItems = [image]
        case .allCards:
            var images: [Any] = []
            for index in 0..<10 {
                let renderer = ImageRenderer(content: cardView(at: index))
                renderer.scale = 2.0
                if let image = renderer.uiImage {
                    images.append(image)
                }
            }
            guard !images.isEmpty else { return }
            shareItems = images
        }
        showActivitySheet = true
    }
}

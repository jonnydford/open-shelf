import SwiftUI

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

    @AppStorage("preferredShareFormat") private var preferredFormat: String = ShareFormat.story.rawValue
    @State private var selectedFormat: ShareFormat = .story
    @State private var showActivitySheet = false
    @State private var shareItems: [Any] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                // Preview
                summaryCardView
                    .scaleEffect(previewScale)
                    .frame(width: previewWidth, height: previewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)

                Spacer()

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

    // MARK: - Summary Card

    private var summaryCardView: some View {
        let dims = selectedFormat.dimensions
        return UnwrappedCard {
            VStack(spacing: summarySpacing) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: headerIconSize))
                        .foregroundStyle(Color.accentColor)

                    Text("My \(String(year)) in Books")
                        .font(.system(size: headerFontSize, weight: .bold))
                }

                // Books read
                VStack(spacing: 4) {
                    Text("\(booksReadCount)")
                        .font(.system(size: bigNumberSize, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                    Text("books read")
                        .font(.system(size: labelSize))
                        .foregroundStyle(.secondary)
                }

                // Pages & hours
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

                // Top book (all formats)
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

                // Top genre (all formats)
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

                // Extended stats for non-square formats
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

                // Goal (all formats)
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

                // Branding
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

    // MARK: - Sizing Helpers

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

    // MARK: - Share

    private func renderAndShare() {
        let renderer = ImageRenderer(content: summaryCardView)
        renderer.scale = 2.0
        guard let image = renderer.uiImage else { return }
        shareItems = [image]
        showActivitySheet = true
    }
}

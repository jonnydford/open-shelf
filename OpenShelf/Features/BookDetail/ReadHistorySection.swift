import SwiftUI
import SwiftData

struct ReadHistorySection: View {
    let entries: [ReadEntry]

    @State private var expandedEntryID: PersistentIdentifier?

    private var sortedEntries: [ReadEntry] {
        entries.sorted { lhs, rhs in
            let lhsDate = lhs.finishDate ?? lhs.startDate ?? .distantPast
            let rhsDate = rhs.finishDate ?? rhs.startDate ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Read History")
                    .font(.headline)

                ForEach(sortedEntries) { entry in
                    readEntryRow(entry)
                }
            }
        }
    }

    // MARK: - Entry Row

    private func readEntryRow(_ entry: ReadEntry) -> some View {
        let isExpanded = expandedEntryID == entry.persistentModelID

        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedEntryID = isExpanded ? nil : entry.persistentModelID
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        dateRange(entry)
                        if let dnfPage = entry.dnfPage {
                            Text("Stopped at page \(dnfPage)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    if let rating = entry.rating {
                        compactRatingDisplay(rating)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent(entry)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Date Range

    private func dateRange(_ entry: ReadEntry) -> some View {
        HStack(spacing: 4) {
            if let start = entry.startDate {
                Text(start, style: .date)
                    .font(.subheadline)
            }
            if entry.finishDate != nil || entry.dnfPage != nil {
                Text("\u{2013}")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let finish = entry.finishDate {
                Text(finish, style: .date)
                    .font(.subheadline)
            } else if entry.dnfPage != nil {
                Text("DNF")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
            }
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Compact Rating

    private func compactRatingDisplay(_ rating: Double) -> some View {
        HStack(spacing: 1) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: starName(for: star, rating: rating))
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func starName(for star: Int, rating: Double) -> String {
        if Double(star) <= rating {
            return "star.fill"
        } else if Double(star) - 0.5 <= rating {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    // MARK: - Expanded Content

    private func expandedContent(_ entry: ReadEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()

            if let rating = entry.rating {
                HStack {
                    Text("Rating:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if rating == floor(rating) {
                        Text("\(Int(rating)) / 5")
                            .font(.caption)
                    } else {
                        Text(String(format: "%.1f / 5", rating))
                            .font(.caption)
                    }
                }
            }

            if let dnfReason = entry.dnfReason, !dnfReason.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reason:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dnfReason)
                        .font(.caption)
                }
            }

            if let notes = entry.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notes:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(notes)
                        .font(.caption)
                }
            }
        }
    }
}

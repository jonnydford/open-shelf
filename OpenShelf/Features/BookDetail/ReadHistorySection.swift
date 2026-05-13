import SwiftUI
import SwiftData

struct ReadHistorySection: View {
    let entries: [ReadEntry]
    var book: Book?
    var showHeader: Bool = true

    @Environment(\.modelContext) private var modelContext
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
                if showHeader {
                    Text("Read History")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }

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
            .accessibilityHint(isExpanded ? "Collapses reading session details" : "Expands reading session details")

            if isExpanded {
                expandedContent(entry)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
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
                Label("DNF", systemImage: "xmark.circle")
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
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ratingAccessibilityLabel(rating))
    }

    private func ratingAccessibilityLabel(_ rating: Double) -> String {
        if rating == floor(rating) {
            return "\(Int(rating)) out of 5 stars"
        } else {
            return "\(String(format: "%.1f", rating)) out of 5 stars"
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

            ReadEntryRatingEditor(entry: entry, book: book, modelContext: modelContext)

            if let dnfReason = entry.dnfReason, !dnfReason.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reason:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(dnfReason)
                        .font(.caption)
                }
            }

            ReadEntryNotesEditor(entry: entry)
        }
    }
}

// MARK: - Read Entry Rating Editor

private struct ReadEntryRatingEditor: View {
    let entry: ReadEntry
    let book: Book?
    let modelContext: ModelContext

    private var ratingBinding: Binding<Double?> {
        Binding(
            get: { entry.rating },
            set: { newValue in
                entry.rating = newValue
                syncToBook(newValue)
                try? modelContext.save()
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rating:")
                .font(.caption)
                .foregroundStyle(.secondary)

            RatingPicker(rating: ratingBinding, mode: .interactive)
                .accessibilityLabel("Rating for this read")
        }
    }

    private func syncToBook(_ rating: Double?) {
        guard let book else { return }
        let sorted = (book.reads ?? []).sorted {
            ($0.finishDate ?? $0.startDate ?? .distantPast) > ($1.finishDate ?? $1.startDate ?? .distantPast)
        }
        if sorted.first?.persistentModelID == entry.persistentModelID {
            book.userRating = rating
        }
    }
}

// MARK: - Read Entry Notes Editor

private struct ReadEntryNotesEditor: View {
    let entry: ReadEntry
    @Environment(\.modelContext) private var modelContext
    @FocusState private var isFocused: Bool

    private var notesBinding: Binding<String> {
        Binding(
            get: { entry.notes ?? "" },
            set: { entry.notes = $0.isEmpty ? nil : $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                TextEditor(text: notesBinding)
                    .focused($isFocused)
                    .font(.caption)
                    .frame(minHeight: 60)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))

                if entry.notes == nil || entry.notes?.isEmpty == true {
                    Text("Notes for this read...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                try? modelContext.save()
            }
        }
    }
}

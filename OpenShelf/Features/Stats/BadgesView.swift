import SwiftUI
import SwiftData

struct BadgesView: View {
    let badges: [Badge]

    @State private var newlyViewed: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                badgeSummary
                badgeGrid
            }
            .padding()
        }
        .navigationTitle("Badges")
    }

    // MARK: - Summary

    private var badgeSummary: some View {
        let unlocked = badges.filter(\.isUnlocked).count
        return VStack(spacing: 4) {
            Text("\(unlocked) of \(badges.count)")
                .font(.title.bold())
            Text("badges earned")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Grid

    private var badgeGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(badges) { badge in
                BadgeCell(badge: badge, isNewlyViewed: newlyViewed.contains(badge.id), reduceMotion: reduceMotion)
                    .onAppear {
                        if badge.isUnlocked && !newlyViewed.contains(badge.id) {
                            withAnimation(.spring(duration: 0.5, bounce: 0.4).delay(0.2)) {
                                newlyViewed.insert(badge.id)
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Badge Cell

private struct BadgeCell: View {
    let badge: Badge
    let isNewlyViewed: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: badge.icon)
                    .font(.title2)
                    .foregroundStyle(badge.isUnlocked ? Color.accentColor : .gray.opacity(0.4))
            }
            .scaleEffect(isNewlyViewed && !reduceMotion ? 1.0 : (badge.isUnlocked ? 0.8 : 1.0))

            Text(badge.title)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(badge.isUnlocked ? .primary : .secondary)

            Text(badge.description)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .opacity(badge.isUnlocked ? 1.0 : 0.5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(badge.title): \(badge.description)")
        .accessibilityValue(badge.isUnlocked ? "Earned" : "Locked")
    }
}

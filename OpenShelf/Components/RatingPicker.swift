import SwiftUI

enum RatingPickerMode {
    case interactive       // Large stars, tappable/draggable (detail view)
    case compactInteractive // Medium stars, tappable only (reading history)
    case compact           // Small stars, display-only (list row)
}

struct RatingPicker: View {
    @Binding var rating: Double?
    var mode: RatingPickerMode = .interactive

    @ScaledMetric(relativeTo: .body) private var interactiveSize: CGFloat = 28
    @ScaledMetric(relativeTo: .subheadline) private var compactInteractiveSize: CGFloat = 18
    @ScaledMetric(relativeTo: .caption2) private var compactSize: CGFloat = 12

    @State private var dragRating: Double?

    private var starSize: CGFloat {
        switch mode {
        case .interactive: interactiveSize
        case .compactInteractive: compactInteractiveSize
        case .compact: compactSize
        }
    }

    private var starSpacing: CGFloat {
        switch mode {
        case .interactive: 6
        case .compactInteractive: 3
        case .compact: 1
        }
    }

    private var isInteractive: Bool {
        mode == .interactive || mode == .compactInteractive
    }

    private var displayRating: Double {
        dragRating ?? rating ?? 0
    }

    var body: some View {
        HStack(spacing: starSpacing) {
            ForEach(1...5, id: \.self) { star in
                starImage(for: star)
                    .font(.system(size: starSize))
                    .foregroundStyle(.yellow)
            }
        }
        .if(isInteractive) { view in
            view
                .contentShape(Rectangle())
                .onTapGesture { location in
                    handleTap(at: location)
                }
        }
        .if(mode == .interactive) { view in
            view.gesture(dragGesture)
        }
        .accessibilityElement()
        .accessibilityLabel("Rating")
        .accessibilityValue(accessibilityValueText)
        .if(isInteractive) { view in
            view.accessibilityAdjustableAction { direction in
                handleAccessibilityAdjust(direction)
            }
        }
        .if(isInteractive) { view in
            view.sensoryFeedback(.selection, trigger: rating)
        }
    }

    // MARK: - Star Image

    private func starImage(for star: Int) -> Image {
        let value = displayRating
        if Double(star) <= value {
            return Image(systemName: "star.fill")
        } else if Double(star) - 0.5 <= value {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }

    // MARK: - Tap Handling

    private func handleTap(at location: CGPoint) {
        let totalWidth = CGFloat(5) * starSize + CGFloat(4) * starSpacing
        let tapped = ratingFromX(location.x, totalWidth: totalWidth)

        withAnimation(.easeInOut(duration: 0.15)) {
            if rating == tapped {
                // Tap current rating again -> clear
                rating = nil
            } else {
                rating = tapped
            }
        }
    }

    // MARK: - Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let totalWidth = CGFloat(5) * starSize + CGFloat(4) * starSpacing
                let newRating = ratingFromX(value.location.x, totalWidth: totalWidth)
                if newRating != dragRating {
                    dragRating = newRating
                }
            }
            .onEnded { value in
                if let final = dragRating {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        rating = final
                    }
                }
                dragRating = nil
            }
    }

    // MARK: - Position -> Rating

    private func ratingFromX(_ x: CGFloat, totalWidth: CGFloat) -> Double {
        let clamped = max(0, min(x, totalWidth))
        let starWidth = starSize + starSpacing
        let starIndex = clamped / starWidth
        let fraction = starIndex - floor(starIndex)
        let base = floor(starIndex)

        let value: Double
        if fraction < 0.5 {
            value = base + 0.5
        } else {
            value = base + 1.0
        }

        return max(0.5, min(5.0, value))
    }

    // MARK: - Accessibility

    private var accessibilityValueText: String {
        guard let rating else { return "No rating" }
        if rating == floor(rating) {
            return "\(Int(rating)) out of 5 stars"
        } else {
            return String(format: "%.1f out of 5 stars", rating)
        }
    }

    private func handleAccessibilityAdjust(_ direction: AccessibilityAdjustmentDirection) {
        switch direction {
        case .increment:
            let current = rating ?? 0
            if current < 5 {
                withAnimation {
                    rating = min(5.0, current + 0.5)
                }
            }
        case .decrement:
            let current = rating ?? 0
            if current > 0.5 {
                withAnimation {
                    rating = current - 0.5
                }
            } else {
                withAnimation {
                    rating = nil
                }
            }
        @unknown default:
            break
        }
    }
}

// MARK: - Conditional View Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

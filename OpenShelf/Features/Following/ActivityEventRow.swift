import SwiftUI

struct ActivityEventRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: 12) {
            initialsAvatar

            VStack(alignment: .leading, spacing: 2) {
                Text(eventMessage)
                    .font(.subheadline)
                    .lineLimit(3)

                if (event.eventType == .rated || event.eventType == .finished), let rating = event.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                Text(event.timestamp, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            if event.bookCoverID != nil {
                CoverImage(coverID: event.bookCoverID, size: .small)
                    .frame(width: 32, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 4)
    }

    private var initialsAvatar: some View {
        let initial = event.friendDisplayName.first.map(String.init) ?? "?"
        return Circle()
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: 36, height: 36)
            .overlay {
                Text(initial)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
            }
    }

    private var eventMessage: AttributedString {
        let name = event.friendDisplayName
        switch event.eventType {
        case .started:
            return buildMessage("\(name) started reading ", title: event.bookTitle)
        case .finished:
            return buildMessage("\(name) finished ", title: event.bookTitle)
        case .rated:
            return buildMessage("\(name) rated ", title: event.bookTitle)
        case .goal:
            var result = AttributedString("\(name) reached their reading goal!")
            if let range = result.range(of: name) {
                result[range].font = .subheadline.bold()
            }
            return result
        }
    }

    private func buildMessage(_ prefix: String, title: String) -> AttributedString {
        var result = AttributedString(prefix)
        var titlePart = AttributedString(title)
        titlePart.font = .subheadline.italic()
        result.append(titlePart)

        let name = event.friendDisplayName
        if let range = result.range(of: name) {
            result[range].font = .subheadline.bold()
        }
        return result
    }
}

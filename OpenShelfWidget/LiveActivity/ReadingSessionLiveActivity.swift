import ActivityKit
import WidgetKit
import SwiftUI

struct ReadingSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingSessionAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.8))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "book.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.bookTitle)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.attributes.authorName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if let pageCount = context.attributes.pageCount, pageCount > 0 {
                            let progress = Double(context.state.currentPage) / Double(pageCount)
                            Gauge(value: progress) {
                                Text("")
                            }
                            .gaugeStyle(.accessoryCircularCapacity)
                            .tint(.green)
                            .frame(width: 44, height: 44)
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("Page \(context.state.currentPage)", systemImage: "bookmark.fill")
                            .font(.caption)
                        Spacer()
                        Text(context.state.startedAt, style: .timer)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "book.fill")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                Group {
                    if let pageCount = context.attributes.pageCount, pageCount > 0 {
                        let pct = Int(Double(context.state.currentPage) / Double(pageCount) * 100)
                        Text("\(pct)%")
                    } else {
                        Text("p.\(context.state.currentPage)")
                    }
                }
                .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "book.fill")
                    .foregroundStyle(.tint)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<ReadingSessionAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "book.fill")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.bookTitle)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 16) {
                    Label("Page \(context.state.currentPage)", systemImage: "bookmark.fill")
                        .font(.caption)
                    if let pageCount = context.attributes.pageCount, pageCount > 0 {
                        let pct = Int(Double(context.state.currentPage) / Double(pageCount) * 100)
                        Text("\(pct)%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(context.state.startedAt, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

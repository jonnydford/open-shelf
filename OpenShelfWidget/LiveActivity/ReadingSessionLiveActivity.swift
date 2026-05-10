import ActivityKit
import WidgetKit
import SwiftUI

struct ReadingSessionLiveActivity: Widget {
    private func deepLink(for context: ActivityViewContext<ReadingSessionAttributes>) -> URL? {
        let path = context.attributes.olWorkKey.replacingOccurrences(of: "/works/", with: "")
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "openshelf://book/\(encoded)")
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingSessionAttributes.self) { context in
            lockScreenView(context: context)
                .widgetURL(deepLink(for: context))
                .activityBackgroundTint(.black.opacity(0.8))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.isAudiobook ? "headphones" : "book.fill")
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
                        if context.attributes.isAudiobook {
                            if let chapterCount = context.attributes.chapterCount, chapterCount > 0,
                               let currentChapter = context.state.currentChapter {
                                let progress = Double(currentChapter) / Double(chapterCount)
                                Gauge(value: progress) {
                                    Text("")
                                }
                                .gaugeStyle(.accessoryCircularCapacity)
                                .tint(.purple)
                                .frame(width: 44, height: 44)
                            }
                        } else if let pageCount = context.attributes.pageCount, pageCount > 0 {
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
                        if context.attributes.isAudiobook {
                            if let currentChapter = context.state.currentChapter {
                                Label("Chapter \(currentChapter)", systemImage: "headphones")
                                    .font(.caption)
                            } else {
                                Label("Listening", systemImage: "headphones")
                                    .font(.caption)
                            }
                        } else {
                            Label("Page \(context.state.currentPage)", systemImage: "bookmark.fill")
                                .font(.caption)
                        }
                        Spacer()
                        Text(context.state.startedAt, style: .timer)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.isAudiobook ? "headphones" : "book.fill")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                Group {
                    if context.attributes.isAudiobook {
                        if let chapterCount = context.attributes.chapterCount, chapterCount > 0,
                           let currentChapter = context.state.currentChapter {
                            let pct = Int(Double(currentChapter) / Double(chapterCount) * 100)
                            Text("\(pct)%")
                        } else if let currentChapter = context.state.currentChapter {
                            Text("Ch.\(currentChapter)")
                        } else {
                            Image(systemName: "headphones")
                        }
                    } else if let pageCount = context.attributes.pageCount, pageCount > 0 {
                        let pct = Int(Double(context.state.currentPage) / Double(pageCount) * 100)
                        Text("\(pct)%")
                    } else {
                        Text("p.\(context.state.currentPage)")
                    }
                }
                .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: context.attributes.isAudiobook ? "headphones" : "book.fill")
                    .foregroundStyle(.tint)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<ReadingSessionAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: context.attributes.isAudiobook ? "headphones" : "book.fill")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.bookTitle)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 16) {
                    if context.attributes.isAudiobook {
                        if let currentChapter = context.state.currentChapter {
                            Label("Chapter \(currentChapter)", systemImage: "headphones")
                                .font(.caption)
                        } else {
                            Label("Listening", systemImage: "headphones")
                                .font(.caption)
                        }
                        if let chapterCount = context.attributes.chapterCount, chapterCount > 0,
                           let currentChapter = context.state.currentChapter {
                            let pct = Int(Double(currentChapter) / Double(chapterCount) * 100)
                            Text("\(pct)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label("Page \(context.state.currentPage)", systemImage: "bookmark.fill")
                            .font(.caption)
                        if let pageCount = context.attributes.pageCount, pageCount > 0 {
                            let pct = Int(Double(context.state.currentPage) / Double(pageCount) * 100)
                            Text("\(pct)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(context.state.startedAt, style: .timer)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lockScreenAccessibilityLabel(context: context))
    }

    private func lockScreenAccessibilityLabel(context: ActivityViewContext<ReadingSessionAttributes>) -> String {
        if context.attributes.isAudiobook {
            var label = "Listening to \(context.attributes.bookTitle)"
            if let currentChapter = context.state.currentChapter {
                label += ", chapter \(currentChapter)"
            }
            if let chapterCount = context.attributes.chapterCount, chapterCount > 0,
               let currentChapter = context.state.currentChapter {
                let pct = Int(Double(currentChapter) / Double(chapterCount) * 100)
                label += ", \(pct) percent complete"
            }
            return label
        } else {
            var label = "Reading \(context.attributes.bookTitle)"
            label += ", page \(context.state.currentPage)"
            if let pageCount = context.attributes.pageCount, pageCount > 0 {
                let pct = Int(Double(context.state.currentPage) / Double(pageCount) * 100)
                label += ", \(pct) percent complete"
            }
            return label
        }
    }
}

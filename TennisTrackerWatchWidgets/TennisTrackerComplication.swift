import SwiftUI
import WidgetKit

private struct TennisEntry: TimelineEntry {
    let date: Date
    let glance: TennisGlance
    var relevance: TimelineEntryRelevance? { TimelineEntryRelevance(score: glance.relevanceScore, duration: 60) }
}

private struct TennisTimeline: TimelineProvider {
    func placeholder(in context: Context) -> TennisEntry {
        TennisEntry(date: .now, glance: TennisGlance.make(snapshot: .empty))
    }
    func getSnapshot(in context: Context, completion: @escaping (TennisEntry) -> Void) {
        completion(entry(at: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TennisEntry>) -> Void) {
        let now = Date()
        let snapshot = TennisSharedSnapshotFile.read() ?? .empty
        let entries = (0..<60).map { minute in
            let date = now.addingTimeInterval(Double(minute) * 60)
            return TennisEntry(date: date, glance: TennisGlance.make(snapshot: snapshot, now: date))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600))))
    }
    private func entry(at date: Date) -> TennisEntry {
        TennisEntry(date: date, glance: TennisGlance.make(snapshot: TennisSharedSnapshotFile.read() ?? .empty, now: date))
    }
}

private struct TennisComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TennisEntry

    var body: some View {
        Group {
            if family == .accessoryInline {
                Text("\(entry.glance.title): \(entry.glance.detail)")
            } else if family == .accessoryCorner {
                Image(systemName: "tennisball.fill")
                    .widgetAccentable()
                    .widgetLabel { Text(entry.glance.circularDetail) }
            } else if family == .accessoryCircular {
                VStack {
                    Image(systemName: "tennisball.fill")
                    Text(entry.glance.circularDetail).font(.caption2).lineLimit(2).minimumScaleFactor(0.7)
                }
            } else {
                VStack(alignment: .leading) {
                    Label(entry.glance.title, systemImage: "tennisball.fill").font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                    Text(entry.glance.detail).lineLimit(2).minimumScaleFactor(0.7)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.glance.accessibilitySummary)
        .privacySensitive()
        .widgetURL(entry.glance.destination.url)
    }
}

@main
struct TennisTrackerComplication: Widget {
    let kind = "TennisTrackerComplication"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TennisTimeline()) { TennisComplicationView(entry: $0) }
            .configurationDisplayName("Tennis Tracker")
            .description("Your current tennis activity or next event.")
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

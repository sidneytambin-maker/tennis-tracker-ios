import SwiftUI
import WidgetKit

private struct TennisEntry: TimelineEntry {
    let date: Date
    let glance: TennisGlance
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
        let entries = (0..<15).map { entry(at: now.addingTimeInterval(Double($0) * 60)) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
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
            } else if family == .accessoryCircular {
                VStack {
                    Image(systemName: "tennisball.fill")
                    Text(entry.glance.detail).font(.caption2).lineLimit(2).minimumScaleFactor(0.7)
                }
            } else {
                VStack(alignment: .leading) {
                    Label(entry.glance.title, systemImage: "tennisball.fill").font(.headline).lineLimit(1)
                    Text(entry.glance.detail).lineLimit(2)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.glance.accessibilitySummary)
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
            .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

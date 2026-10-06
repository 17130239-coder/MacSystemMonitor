import WidgetKit
import SwiftUI

struct MetricsEntry: TimelineEntry {
    let date: Date
    let metrics: SystemMetrics
    /// True when the app has not written a recent snapshot (not running / never run).
    let isStale: Bool
}

/// The widget never touches sensors itself (the widget sandbox forbids IOKit SMC/HID
/// access). It renders the latest snapshot written by the main app.
///
/// WidgetKit refresh limits: macOS decides when a timeline may reload. The app asks
/// for a reload about once a minute and the timeline below also requests one after
/// 60 s, but the system can and will throttle this. The widget is therefore a
/// near-real-time glance; the app window is the real-time (1 s) view.
struct MetricsProvider: TimelineProvider {
    func placeholder(in context: Context) -> MetricsEntry {
        MetricsEntry(date: Date(), metrics: .empty, isStale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (MetricsEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MetricsEntry>) -> Void) {
        let entry = currentEntry()
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(15))))
    }

    private func currentEntry() -> MetricsEntry {
        let now = Date()
        guard let metrics = SnapshotStore.load() else {
            return MetricsEntry(date: now, metrics: .empty, isStale: true)
        }
        let stale = now.timeIntervalSince(metrics.timestamp) > SnapshotStore.staleAfter
        return MetricsEntry(date: now, metrics: metrics, isStale: stale)
    }
}

struct MetricsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MetricsEntry

    var body: some View {
        MonitorWidgetView(metrics: entry.metrics,
                          statusOverride: entry.isStale ? "Open app" : nil,
                          density: density)
            .containerBackground(for: .widget) { MonitorTheme.background }
    }

    private var density: MonitorDensity {
        switch family {
        case .systemSmall: return .small
        case .systemLarge, .systemExtraLarge: return .large
        default: return .regular
        }
    }
}

/// ONE widget, three adaptive layouts.
@main
struct MacSystemMonitorWidget: Widget {
    let kind = "MacSystemMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MetricsProvider()) { entry in
            MetricsWidgetView(entry: entry)
        }
        .configurationDisplayName("Mac Monitor")
        .description("CPU, GPU, RAM, battery, SSD temperature and fan speed. Updated by the Mac Monitor app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

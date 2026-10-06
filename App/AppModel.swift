import AppKit
import Foundation
import WidgetKit

/// App-wide singleton owning the monitor so it lives independently of any window.
@MainActor
final class AppModel {
    static let shared = AppModel()

    let monitor = SystemMonitor()
    private let publisher = WidgetPublisher()

    /// Interval the user picked in Settings.
    private(set) var userInterval: Duration
    /// While no window is visible, sampling at 5s keeps data fresh with virtually zero CPU.
    private let backgroundInterval: Duration = .seconds(5)

    static let intervalDefaultsKey = "refreshIntervalSeconds"

    private init() {
        let stored = UserDefaults.standard.double(forKey: Self.intervalDefaultsKey)
        userInterval = .seconds(stored > 0 ? stored : 1)
    }

    func start() {
        monitor.onSample = { [publisher] metrics in publisher.publish(metrics) }
        applyInterval()
        monitor.start()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeOcclusionStateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyInterval() }
        }
    }

    func setRefreshInterval(seconds: Double) {
        userInterval = .seconds(max(0.5, seconds))
        applyInterval()
    }

    private func applyInterval() {
        let visible = NSApp?.occlusionState.contains(.visible) ?? true
        monitor.refreshInterval = visible ? userInterval : backgroundInterval
    }
}

/// Writes the snapshot the widget reads and asks WidgetKit to reload.
///
/// WidgetKit is not an arbitrary 1-second continuous canvas (macOS budgets reloads
/// to preserve battery life). We save the disk snapshot continuously so any widget
/// read gets immediate fresh data, and request WidgetKit timeline reloads every 15s.
@MainActor
final class WidgetPublisher {
    private var lastReload = Date.distantPast
    private var lastSave = Date.distantPast
    private let reloadInterval: TimeInterval = 15
    private let saveInterval: TimeInterval = 2

    func publish(_ metrics: SystemMetrics) {
        let now = Date()
        if now.timeIntervalSince(lastSave) >= saveInterval {
            lastSave = now
            SnapshotStore.save(metrics)
        }
        guard now.timeIntervalSince(lastReload) >= reloadInterval else { return }
        lastReload = now
        WidgetCenter.shared.reloadTimelines(ofKind: "MacSystemMonitorWidget")
    }
}

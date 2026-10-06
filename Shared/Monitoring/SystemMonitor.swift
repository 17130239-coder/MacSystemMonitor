import Foundation
import Observation

/// Source of truth for real-time monitoring. Samples on a background actor and
/// publishes to the UI on the main actor, only when something actually changed.
@MainActor
@Observable
final class SystemMonitor {
    private(set) var metrics: SystemMetrics = .empty

    /// Sampling interval. Can be changed at any time; applies from the next cycle.
    var refreshInterval: Duration = .seconds(1)

    /// Called on the main actor after every sample (used by the app to feed the widget).
    @ObservationIgnored var onSample: ((SystemMetrics) -> Void)?

    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let makeSampler: @Sendable () -> SystemSampler

    init(makeSampler: @escaping @Sendable () -> SystemSampler = { SystemSampler.live() }) {
        self.makeSampler = makeSampler
    }

    func start() {
        guard task == nil else { return }
        let factory = makeSampler
        task = Task { [weak self] in
            let engine = SamplingEngine(makeSampler: factory)
            while !Task.isCancelled {
                let latest = await engine.sample()
                guard let self else { return }
                if latest != self.metrics { self.metrics = latest }   // avoids redundant SwiftUI redraws
                self.onSample?(latest)
                try? await Task.sleep(for: self.refreshInterval, tolerance: .milliseconds(150))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

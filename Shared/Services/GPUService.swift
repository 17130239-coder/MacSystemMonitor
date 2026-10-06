import Foundation
import IOKit

protocol GPUStatsSource {
    /// Utilisation 0...100, or nil when no GPU accelerator exposes statistics.
    func readUtilization() -> Double?
}

/// Reads `PerformanceStatistics["Device Utilization %"]` from every `IOAccelerator`
/// registry entry (the Apple Silicon GPU driver, `AGXAccelerator`). This is the same
/// figure Activity Monitor's GPU history is based on. Public IOKit registry API, no
/// permissions, works on M1 and later.
struct IOAcceleratorStatsSource: GPUStatsSource {
    func readUtilization() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var best: Double?
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            guard let stats = IORegistryEntryCreateCFProperty(entry, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] else { continue }
            let number = (stats["Device Utilization %"] ?? stats["GPU Activity(%)"]) as? NSNumber
            if let value = number?.doubleValue {
                best = max(best ?? 0, value)
            }
        }
        return best
    }
}

final class GPUService {
    private let source: GPUStatsSource
    init(source: GPUStatsSource = IOAcceleratorStatsSource()) { self.source = source }

    func sample() -> SensorValue<Double> {
        guard let value = source.readUtilization() else {
            return .unavailable("No IOAccelerator exposes GPU performance statistics.")
        }
        return .available(min(100, max(0, value)))
    }
}

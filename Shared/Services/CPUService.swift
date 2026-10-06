import Foundation
import Darwin

/// Cumulative CPU scheduler ticks, summed over all logical cores.
struct CPUTicks: Equatable, Sendable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64

    var busy: UInt64 { user + system + nice }
    var total: UInt64 { busy + idle }
}

protocol CPUTickSource {
    func readTicks() -> CPUTicks?
}

enum CPUUsageCalculator {
    /// Utilisation (0...100) between two cumulative tick snapshots:
    /// `busy delta / total delta`, where busy = user + system + nice.
    /// Returns nil when no time elapsed or the counters went backwards (wrap-around).
    static func usage(from previous: CPUTicks, to current: CPUTicks) -> Double? {
        guard current.user >= previous.user, current.system >= previous.system,
              current.idle >= previous.idle, current.nice >= previous.nice else { return nil }
        let busy = current.busy - previous.busy
        let total = current.total - previous.total
        guard total > 0 else { return nil }
        return min(100, max(0, Double(busy) / Double(total) * 100))
    }
}

/// Real CPU ticks from the Mach kernel via `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`.
/// No permissions required; identical on Intel and Apple Silicon (counts E- and P-cores).
struct HostCPUTickSource: CPUTickSource {
    func readTicks() -> CPUTicks? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        var ticks = CPUTicks(user: 0, system: 0, idle: 0, nice: 0)
        let stride = Int(CPU_STATE_MAX)
        for core in 0 ..< Int(cpuCount) {
            let base = core * stride
            ticks.user += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            ticks.system += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            ticks.idle += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            ticks.nice += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
        }
        return ticks
    }
}

/// Stateful CPU usage sampler. Each `sample()` measures the interval since the
/// previous call, then applies a light exponential moving average so the number
/// is stable instead of twitching with every scheduler burst.
final class CPUService {
    private let source: CPUTickSource
    /// Weight of the newest measurement (1 = no smoothing).
    private let smoothing: Double
    private var previous: CPUTicks?
    private var smoothed: Double?

    init(source: CPUTickSource = HostCPUTickSource(), smoothing: Double = 0.6) {
        self.source = source
        self.smoothing = smoothing
        self.previous = source.readTicks()   // baseline so the first sample() has an interval
    }

    func sample() -> SensorValue<Double> {
        guard let current = source.readTicks() else {
            return .error("host_processor_info failed.")
        }
        defer { previous = current }
        guard let previous, let raw = CPUUsageCalculator.usage(from: previous, to: current) else {
            if let smoothed { return .available(smoothed) }
            return .unavailable("Collecting first sample.")
        }
        let value = smoothed.map { $0 + smoothing * (raw - $0) } ?? raw
        smoothed = value
        return .available(value)
    }
}

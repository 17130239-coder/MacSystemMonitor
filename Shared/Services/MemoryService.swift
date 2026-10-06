import Foundation
import Darwin

/// Raw page counters from `host_statistics64(HOST_VM_INFO64)`.
struct VMStatistics: Equatable, Sendable {
    var internalPages: UInt64      // anonymous pages ("app memory" incl. purgeable)
    var purgeablePages: UInt64
    var wiredPages: UInt64
    var compressedPages: UInt64    // pages occupied by the compressor
    var pageSize: UInt64
}

protocol VMStatisticsSource {
    func read() -> VMStatistics?
}

enum MemoryCalculator {
    /// "Used" RAM, defined exactly like Activity Monitor's **Memory Used**:
    ///
    ///     used = App Memory + Wired + Compressed
    ///          = (internal − purgeable) + wired + compressor
    ///
    /// This is the memory-pressure-aware view: file cache (inactive/cached files)
    /// and purgeable memory are reclaimable, so they are *not* counted as used.
    static func usedBytes(_ s: VMStatistics) -> UInt64 {
        let app = s.internalPages >= s.purgeablePages ? s.internalPages - s.purgeablePages : 0
        return (app + s.wiredPages + s.compressedPages) * s.pageSize
    }
}

struct HostVMStatisticsSource: VMStatisticsSource {
    func read() -> VMStatistics? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS, pageSize > 0 else { return nil }
        return VMStatistics(
            internalPages: UInt64(stats.internal_page_count),
            purgeablePages: UInt64(stats.purgeable_count),
            wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count),
            pageSize: UInt64(pageSize)
        )
    }
}

final class MemoryService {
    private let source: VMStatisticsSource
    private let totalBytes: UInt64

    /// `totalBytes` defaults to `ProcessInfo.physicalMemory` (detected, never hard-coded).
    init(source: VMStatisticsSource = HostVMStatisticsSource(),
         totalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory) {
        self.source = source
        self.totalBytes = totalBytes
    }

    func sample() -> SensorValue<MemoryUsage> {
        guard totalBytes > 0 else { return .error("Physical memory size is unknown.") }
        guard let stats = source.read() else { return .error("host_statistics64 failed.") }
        let used = min(MemoryCalculator.usedBytes(stats), totalBytes)
        return .available(MemoryUsage(usedBytes: used, totalBytes: totalBytes))
    }
}

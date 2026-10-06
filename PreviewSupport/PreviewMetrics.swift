#if DEBUG
import SwiftUI

/// Hard-coded sample data for SwiftUI previews ONLY.
/// Compiled in DEBUG builds, never referenced by production code paths.
enum PreviewMetrics {
    static let hardware = HardwareInfo(
        modelIdentifier: "MacBookPro18,1", modelName: "MacBook Pro", chipName: "Apple M1 Pro",
        physicalMemoryBytes: 16 << 30, hasBattery: true, hasFan: true, fanCount: 2, discoveredSensors: [])

    static let typical = SystemMetrics(
        hardware: hardware,
        cpuUsage: .available(24), cpuTemperature: .available(58.4),
        gpuUsage: .available(12), gpuTemperature: .available(52.2),
        memory: .available(MemoryUsage(usedBytes: UInt64(8.4 * Double(1 << 30)), totalBytes: 16 << 30)),
        battery: BatteryMetrics(percent: .available(86), temperature: .available(34), chargingState: .charging),
        ssdTemperature: .available(41),
        fan: FanMetrics(presence: .present, fanCount: 2, rpm: .available(1820)),
        status: .normal, timestamp: Date())

    static var fanlessPartial: SystemMetrics {
        var m = typical
        m.hardware.modelName = "MacBook Air"
        m.hardware.chipName = "Apple M1"
        m.gpuTemperature = .unavailable("No sensor")
        m.battery.temperature = .unavailable("No sensor")
        m.ssdTemperature = .unavailable("No sensor")
        m.fan = .fanless
        return m
    }
}

#Preview("Regular") {
    MonitorWidgetView(metrics: PreviewMetrics.typical)
        .background(MonitorCardBackground())
        .frame(width: 360, height: 170).padding()
}
#Preview("Large") {
    MonitorWidgetView(metrics: PreviewMetrics.typical)
        .background(MonitorCardBackground())
        .frame(width: 360, height: 360).padding()
}
#Preview("Small") {
    MonitorWidgetView(metrics: PreviewMetrics.typical)
        .background(MonitorCardBackground())
        .frame(width: 170, height: 170).padding()
}
#Preview("Fanless, partial sensors") {
    MonitorWidgetView(metrics: PreviewMetrics.fanlessPartial)
        .background(MonitorCardBackground())
        .frame(width: 360, height: 170).padding()
}
#endif

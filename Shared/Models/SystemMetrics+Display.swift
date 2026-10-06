import Foundation

/// Presentation helpers: turn `SystemMetrics` into the exact strings the UI shows.
/// Keeping this out of the views makes it unit-testable.
struct UsageDisplay: Equatable {
    var text: String
    /// 0...1, or nil when the value is unavailable.
    var fraction: Double?
    var detail: String?
}

extension SystemMetrics {
    private func usage(_ sensor: SensorValue<Double>) -> UsageDisplay {
        guard sensor.isAvailable, let v = sensor.value else {
            return UsageDisplay(text: "N/A", fraction: nil, detail: sensor.detail)
        }
        return UsageDisplay(text: PercentFormatter.string(v), fraction: PercentFormatter.fraction(v), detail: nil)
    }

    var cpuDisplay: UsageDisplay { usage(cpuUsage) }
    var gpuDisplay: UsageDisplay { usage(gpuUsage) }

    var memoryDisplay: UsageDisplay {
        guard memory.isAvailable, let m = memory.value else {
            return UsageDisplay(text: "N/A", fraction: nil, detail: memory.detail)
        }
        return UsageDisplay(text: PercentFormatter.string(m.percent),
                            fraction: PercentFormatter.fraction(m.percent),
                            detail: ByteFormatter.memoryString(used: m.usedBytes, total: m.totalBytes))
    }

    var cpuTemperatureText: String { TemperatureFormatter.string(cpuTemperature) }
    var gpuTemperatureText: String { TemperatureFormatter.string(gpuTemperature) }
    var ssdTemperatureText: String { TemperatureFormatter.string(ssdTemperature) }
    var batteryTemperatureText: String { TemperatureFormatter.string(battery.temperature) }

    var batteryPercentText: String {
        battery.percent.isAvailable ? PercentFormatter.string(battery.percent.value ?? 0) : "N/A"
    }

    /// Subtle suffix shown next to the battery label.
    var batteryStateText: String? {
        guard battery.percent.isAvailable else { return nil }
        return battery.chargingState == .charging ? "Charging" : nil
    }

    /// Big value in the Fan cell: "1820", "Fanless" or "N/A".
    var fanValueText: String {
        switch fan.presence {
        case .fanless: return "Fanless"
        case .present, .unknown:
            guard fan.rpm.isAvailable, let rpm = fan.rpm.value else { return "N/A" }
            return String(Int(rpm.rounded()))
        }
    }

    /// Small caption below the fan value: "RPM" only when a number is shown.
    var fanCaptionText: String? {
        fan.presence == .present && fan.rpm.isAvailable ? "RPM" : nil
    }
}

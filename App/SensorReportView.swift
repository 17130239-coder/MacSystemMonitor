import SwiftUI

/// Diagnostics: exactly what was detected and, for every metric, why it is (un)available.
struct SensorReportView: View {
    var monitor: SystemMonitor

    var body: some View {
        let m = monitor.metrics
        Form {
            Section("Hardware") {
                row("Model", "\(m.hardware.modelName) (\(m.hardware.modelIdentifier))")
                row("Chip", m.hardware.chipName)
                row("Memory", "\(ByteFormatter.gigabytes(Double(m.hardware.physicalMemoryBytes) / ByteFormatter.gibibyte)) GB")
                row("Battery", m.hardware.hasBattery ? "Present" : "Not present")
                row("Fan", fanText(m.hardware))
            }
            Section("Metrics") {
                metric("CPU usage", m.cpuUsage)
                metric("CPU temperature", m.cpuTemperature)
                metric("GPU usage", m.gpuUsage)
                metric("GPU temperature", m.gpuTemperature)
                metric("RAM", m.memory.isAvailable ? SensorValue<Double>.available(m.memory.value?.percent ?? 0) : .unavailable(m.memory.detail ?? ""))
                metric("Battery", m.battery.percent)
                metric("Battery temperature", m.battery.temperature)
                metric("SSD temperature", m.ssdTemperature)
                row("Fan", m.fanValueText + (m.fan.rpm.isAvailable ? "" : reason(m.fan.rpm)))
            }
            Section("Discovered temperature sensors") {
                if m.hardware.discoveredSensors.isEmpty {
                    Text("None").foregroundStyle(.secondary)
                }
                ForEach(TemperatureCategory.allCases, id: \.self) { category in
                    let names = m.hardware.discoveredSensors.filter { $0.category == category }
                    if !names.isEmpty {
                        row(category.rawValue.uppercased(),
                            names.map { "\($0.source):\($0.name)" }.joined(separator: ", "))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 420)
    }

    private func fanText(_ h: HardwareInfo) -> String {
        switch h.hasFan {
        case .some(true): return "\(h.fanCount) fan(s)"
        case .some(false): return "Fanless"
        case .none: return "Unknown"
        }
    }

    private func reason(_ sensor: SensorValue<Double>) -> String {
        sensor.detail.map { " – \($0)" } ?? ""
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label) {
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }

    private func metric(_ label: String, _ sensor: SensorValue<Double>) -> some View {
        row(label, sensor.isAvailable ? "Available" + (sensor.detail.map { " (\($0))" } ?? "")
                                       : "\(sensor.availability.rawValue): \(sensor.detail ?? "")")
    }
}

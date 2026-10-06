import Foundation

struct TemperatureReadings: Sendable, Equatable {
    var cpu: SensorValue<Double>
    var gpu: SensorValue<Double>
    var battery: SensorValue<Double>
    var ssd: SensorValue<Double>
}

/// Reads the sensors found by `SensorDiscoveryService` and aggregates them per category.
///
/// * CPU / GPU / battery: arithmetic mean of the valid sensors in the preferred group.
/// * SSD: the hottest NAND channel (a drive is as hot as its hottest chip).
final class TemperatureService {
    private let probes: [TemperatureProbe]
    private let groupedSensors: [TemperatureCategory: [[DiscoveredSensor]]]
    private let noInterfaceAvailable: Bool

    init(probes: [TemperatureProbe], sensors: [DiscoveredSensor]) {
        self.probes = probes
        self.noInterfaceAvailable = probes.isEmpty

        var grouped: [TemperatureCategory: [[DiscoveredSensor]]] = [:]
        for cat in [TemperatureCategory.cpu, .gpu, .battery, .ssd] {
            let candidates = sensors.filter { $0.classification.category == cat }
            let priorities = Set(candidates.map(\.classification.priority)).sorted()
            grouped[cat] = priorities.map { p in candidates.filter { $0.classification.priority == p } }
        }
        self.groupedSensors = grouped
    }

    func read() -> TemperatureReadings {
        TemperatureReadings(
            cpu: value(for: .cpu, label: "CPU", aggregate: Self.mean),
            gpu: value(for: .gpu, label: "GPU", aggregate: Self.mean),
            battery: value(for: .battery, label: "battery", aggregate: Self.mean),
            ssd: value(for: .ssd, label: "SSD", aggregate: { $0.max() ?? 0 })
        )
    }

    private static func mean(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(values.count)
    }

    private func value(for category: TemperatureCategory, label: String,
                       aggregate: ([Double]) -> Double) -> SensorValue<Double> {
        if noInterfaceAvailable {
            return .unavailable("Neither the IOHID nor the AppleSMC sensor interface could be opened.")
        }
        guard let priorityGroups = groupedSensors[category], !priorityGroups.isEmpty else {
            return .unavailable("macOS does not expose a \(label) temperature sensor on this Mac.")
        }
        for group in priorityGroups {
            let readings = group.compactMap { item -> Double? in
                guard probes.indices.contains(item.probeIndex),
                      let celsius = probes[item.probeIndex].readCelsius(item.sensor),
                      TemperatureFormatter.isPlausible(celsius) else { return nil }
                return celsius
            }
            if !readings.isEmpty {
                let source = group[0].source
                return .available(aggregate(readings), detail: "\(readings.count) \(source) sensor(s)")
            }
        }
        return .error("\(label) temperature sensors were found but returned no valid reading.")
    }
}

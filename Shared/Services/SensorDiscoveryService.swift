import Foundation

struct SensorClassification: Sendable, Equatable {
    var category: TemperatureCategory
    /// Lower = preferred. A category is read from its lowest-priority group that
    /// currently yields valid readings; higher numbers are fallbacks.
    var priority: Int
}

struct DiscoveredSensor: Sendable, Equatable {
    /// Index into the probe list given to discovery.
    var probeIndex: Int
    var source: String
    var sensor: RawSensor
    var classification: SensorClassification
}

/// Finds which temperature sensors this particular Mac exposes and what they measure.
///
/// Apple publishes no sensor map, and names differ between M1/M2/M3/M4 and between
/// Pro/Max/Ultra variants. So instead of hard-coding one key list we enumerate
/// everything the system exposes and classify by naming convention:
///
/// | Category | Primary                         | Fallback                      |
/// |----------|---------------------------------|-------------------------------|
/// | CPU      | SMC `Tp**` / `Te**` (P/E cores) | HID `PMU tdie*`               |
/// | GPU      | SMC `Tg**`                      | – (none)                      |
/// | Battery  | HID `gas gauge battery`         | SMC `TB?T`                    |
/// | SSD      | HID `NAND CH* temp`             | SMC `TH0a/b/x`                |
enum SensorClassifier {
    static func classify(source: String, name: String) -> SensorClassification? {
        switch source {
        case "HID":
            if name.hasPrefix("PMU tdie") { return .init(category: .cpu, priority: 1) }
            if name == "gas gauge battery" { return .init(category: .battery, priority: 1) }
            let lower = name.lowercased()
            if lower.contains("nand"), lower.contains("temp") { return .init(category: .ssd, priority: 0) }
            return nil
        case "SMC":
            guard name.utf8.count == 4 else { return nil }
            if name.hasPrefix("Tp") || name.hasPrefix("Te") { return .init(category: .cpu, priority: 0) }
            if name.hasPrefix("Tg") { return .init(category: .gpu, priority: 0) }
            if name.hasPrefix("TB"), name.hasSuffix("T") { return .init(category: .battery, priority: 2) }
            if name.hasPrefix("TH0") { return .init(category: .ssd, priority: 1) }
            return nil
        default:
            return nil
        }
    }
}

enum SensorDiscoveryService {
    /// Enumerates every probe, classifies the sensors, and keeps only those that
    /// return a plausible value right now (drops unpopulated keys that read 0 °C).
    static func discover(probes: [TemperatureProbe]) -> [DiscoveredSensor] {
        var found: [DiscoveredSensor] = []
        for (index, probe) in probes.enumerated() {
            for sensor in probe.listSensors() {
                guard let classification = SensorClassifier.classify(source: probe.sourceName, name: sensor.name),
                      let value = probe.readCelsius(sensor),
                      TemperatureFormatter.isPlausible(value) else { continue }
                found.append(DiscoveredSensor(probeIndex: index, source: probe.sourceName,
                                              sensor: sensor, classification: classification))
            }
        }
        return found
    }

    static func summaries(of sensors: [DiscoveredSensor]) -> [DiscoveredSensorSummary] {
        sensors.map { DiscoveredSensorSummary(category: $0.classification.category, source: $0.source, name: $0.sensor.name) }
    }
}

import Foundation

/// Static facts about this Mac, detected at launch.
struct HardwareInfo: Codable, Sendable, Equatable {
    /// e.g. "MacBookPro18,1"
    var modelIdentifier: String
    /// e.g. "MacBook Pro"
    var modelName: String
    /// e.g. "Apple M1 Pro"
    var chipName: String
    var physicalMemoryBytes: UInt64
    var hasBattery: Bool
    /// `nil` when it could not be determined (SMC not reachable).
    var hasFan: Bool?
    var fanCount: Int
    /// Names of the temperature sensors that discovery found, grouped by category.
    var discoveredSensors: [DiscoveredSensorSummary]

    /// "MacBook Pro · Apple M1 Pro"
    var headerTitle: String { "\(modelName) · \(chipName)" }

    static let unknown = HardwareInfo(
        modelIdentifier: "Unknown",
        modelName: "Mac",
        chipName: "Apple Silicon",
        physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
        hasBattery: false,
        hasFan: nil,
        fanCount: 0,
        discoveredSensors: []
    )
}

struct DiscoveredSensorSummary: Codable, Sendable, Equatable, Hashable {
    var category: TemperatureCategory
    var source: String
    var name: String
}

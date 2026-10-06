import Foundation

/// Why a sensor does (or does not) have a value.
enum SensorAvailability: String, Codable, Sendable, Equatable {
    /// A real value was read from the system.
    case available
    /// The hardware may have the sensor, but it could not be found / read right now.
    case unavailable
    /// This Mac does not have the hardware at all (e.g. no battery) or macOS exposes no interface for it.
    case unsupported
    /// macOS refused access (sandbox / privileges).
    case permissionDenied
    /// A read was attempted but failed unexpectedly.
    case error
}

/// A single measurement that may legitimately be missing.
///
/// Every metric in the app is a `SensorValue`, so one failing sensor can never
/// take the others down: the UI simply renders `N/A` for that value.
struct SensorValue<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    var availability: SensorAvailability
    var value: Value?
    /// Human readable explanation used for tooltips and the sensor report.
    var detail: String?

    static func available(_ value: Value, detail: String? = nil) -> Self {
        Self(availability: .available, value: value, detail: detail)
    }
    static func unavailable(_ reason: String) -> Self {
        Self(availability: .unavailable, value: nil, detail: reason)
    }
    static func unsupported(_ reason: String) -> Self {
        Self(availability: .unsupported, value: nil, detail: reason)
    }
    static func permissionDenied(_ reason: String) -> Self {
        Self(availability: .permissionDenied, value: nil, detail: reason)
    }
    static func error(_ reason: String) -> Self {
        Self(availability: .error, value: nil, detail: reason)
    }

    var isAvailable: Bool { availability == .available && value != nil }
}

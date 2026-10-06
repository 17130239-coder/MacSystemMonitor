import Foundation

enum TemperatureCategory: String, Codable, Sendable, CaseIterable {
    case cpu, gpu, battery, ssd
}

/// RAM usage. See `MemoryService` for the exact definition of "used".
struct MemoryUsage: Codable, Sendable, Equatable {
    var usedBytes: UInt64
    var totalBytes: UInt64

    /// 0...100
    var percent: Double {
        guard totalBytes > 0 else { return 0 }
        return min(100, max(0, Double(usedBytes) / Double(totalBytes) * 100))
    }
}

enum ChargingState: String, Codable, Sendable, Equatable {
    case charging
    case pluggedIn      // on AC, not charging (full or held by optimised charging)
    case discharging
    case unknown
}

struct PowerAdapterSpecs: Codable, Sendable, Equatable {
    var isConnected: Bool
    var name: String?
    /// Measured current in Amperes (e.g. 2.6 A)
    var currentAmps: SensorValue<Double>
    /// Max rated current in Amperes (e.g. 5.0 A)
    var maxCurrentAmps: Double?
    /// Measured voltage in Volts (e.g. 19.1 V)
    var voltageVolts: SensorValue<Double>
    /// Max rated voltage in Volts (e.g. 20.0 V)
    var maxVoltageVolts: Double?
    /// Measured power in Watts (e.g. 49.3 W)
    var powerWatts: SensorValue<Double>
    /// Max rated power in Watts (e.g. 100.0 W)
    var maxWatts: Double?

    static let disconnected = PowerAdapterSpecs(
        isConnected: false,
        name: nil,
        currentAmps: .unavailable("Disconnected"),
        maxCurrentAmps: nil,
        voltageVolts: .unavailable("Disconnected"),
        maxVoltageVolts: nil,
        powerWatts: .unavailable("Disconnected"),
        maxWatts: nil
    )
}

struct PowerFlow: Codable, Sendable, Equatable {
    var isConnected: Bool
    /// Total power supplied by adapter in Watts (0 when disconnected)
    var adapterWatts: Double
    /// Power going into battery (positive when charging, 0 when idle/full, negative when discharging)
    var batteryWatts: Double
    /// Power consumed by the Mac hardware in Watts
    var systemWatts: Double

    static let zero = PowerFlow(
        isConnected: false,
        adapterWatts: 0,
        batteryWatts: 0,
        systemWatts: 0
    )
}

struct BatteryMetrics: Codable, Sendable, Equatable {
    /// 0...100
    var percent: SensorValue<Double>
    var temperature: SensorValue<Double>
    var chargingState: ChargingState
    var adapter: PowerAdapterSpecs = .disconnected
    var flow: PowerFlow = .zero

    static let notPresent = BatteryMetrics(
        percent: .unsupported("This Mac has no battery."),
        temperature: .unsupported("This Mac has no battery."),
        chargingState: .unknown,
        adapter: .disconnected,
        flow: .zero
    )
}

enum FanPresence: String, Codable, Sendable, Equatable {
    case present
    /// Confirmed to have no physical fan (e.g. MacBook Air).
    case fanless
    /// Could not be determined.
    case unknown
}

struct FanDetail: Codable, Sendable, Equatable {
    var id: Int
    var label: String
    var rpm: Double
    var minRPM: Double?
    var maxRPM: Double?
}

struct FanMetrics: Codable, Sendable, Equatable {
    var presence: FanPresence
    var fanCount: Int
    /// Average RPM across all fans. Only meaningful when `presence == .present`.
    var rpm: SensorValue<Double>
    /// Individual fan readings and limits when available.
    var fans: [FanDetail]? = nil

    static let fanless = FanMetrics(
        presence: .fanless, fanCount: 0,
        rpm: .unsupported("This Mac has no fan."),
        fans: []
    )
}

/// Everything the UI needs to render one frame. Purely data – no logic about
/// how it was obtained.
struct SystemMetrics: Codable, Sendable, Equatable {
    var hardware: HardwareInfo
    var cpuUsage: SensorValue<Double>
    var cpuTemperature: SensorValue<Double>
    var gpuUsage: SensorValue<Double>
    var gpuTemperature: SensorValue<Double>
    var memory: SensorValue<MemoryUsage>
    var battery: BatteryMetrics
    var ssdTemperature: SensorValue<Double>
    var fan: FanMetrics
    var status: SystemStatus
    var timestamp: Date

    /// `timestamp` is deliberately ignored so that identical readings do not
    /// trigger a SwiftUI redraw.
    static func == (l: Self, r: Self) -> Bool {
        l.hardware == r.hardware && l.cpuUsage == r.cpuUsage && l.cpuTemperature == r.cpuTemperature
            && l.gpuUsage == r.gpuUsage && l.gpuTemperature == r.gpuTemperature && l.memory == r.memory
            && l.battery == r.battery && l.ssdTemperature == r.ssdTemperature && l.fan == r.fan
            && l.status == r.status
    }

    /// Every value unavailable. Used before the first sample and as the
    /// WidgetKit placeholder (rendered redacted). This is *not* demo data.
    static let empty: SystemMetrics = {
        let pending = "Waiting for first sample."
        return SystemMetrics(
            hardware: .unknown,
            cpuUsage: .unavailable(pending),
            cpuTemperature: .unavailable(pending),
            gpuUsage: .unavailable(pending),
            gpuTemperature: .unavailable(pending),
            memory: .unavailable(pending),
            battery: BatteryMetrics(percent: .unavailable(pending), temperature: .unavailable(pending), chargingState: .unknown),
            ssdTemperature: .unavailable(pending),
            fan: FanMetrics(presence: .unknown, fanCount: 0, rpm: .unavailable(pending)),
            status: .unknown,
            timestamp: .distantPast
        )
    }()
}

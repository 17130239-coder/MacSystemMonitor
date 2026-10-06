import Foundation

/// Represents the high-level charging intent emitted by the Hysteresis Controller.
/// Decoupled from any specific SMC hardware key or platform mechanism.
public enum ChargingIntent: String, Sendable, Equatable, CaseIterable {
    /// Allow hardware and firmware to charge the battery toward upper limit.
    case enableCharging = "Enable Charging"

    /// Inhibit or gate charging off so battery is not charged while connected to external power.
    case inhibitCharging = "Inhibit Charging"

    /// Actively command the power system to draw energy from the battery even while plugged in.
    case forceDischarge = "Force Discharge"

    /// Maintain the current charging or inhibiting state without modification.
    case holdCurrentState = "Hold State"

    /// Allow macOS firmware and hardware default behavior (e.g., when unplugged or disabled).
    case allowHardwareDefault = "System Default"
}

/// Identifies the runtime-probed SMC key set available on this machine.
public enum SMCKeySetDescription: String, Sendable, Equatable, CaseIterable {
    /// Modern Apple Silicon firmware (e.g., CHTE for charge gating, CHIE for discharge).
    case modernCHTE = "Modern SMC (CHTE / CHIE)"

    /// Legacy Apple Silicon / Intel SMC (e.g., CH0B / CH0C gating, CH0I discharge).
    case legacyCH0B = "Legacy SMC (CH0B / CH0C / CH0I)"

    /// Standard user-space execution without root / helper daemon privileges.
    case readOnlyFallback = "Read-Only / Unprivileged"

    /// In-app simulation mode for verifying hysteresis logic without hardware side effects.
    case simulator = "Simulator Mode"

    public var displayName: String {
        switch self {
        case .modernCHTE:
            return "Modern SMC (CHTE)"
        case .legacyCH0B:
            return "Legacy SMC (CH0B)"
        case .readOnlyFallback:
            return "Telemetry Read-Only"
        case .simulator:
            return "Interactive Simulator"
        }
    }
}

/// Dynamic capabilities probed at runtime rather than inferred solely from CPU model.
public struct BatteryHardwareCapabilities: Sendable, Equatable {
    /// Whether the system has an identified mechanism to inhibit charging.
    public var canInhibitCharge: Bool

    /// Whether the system has an identified mechanism to actively force discharge while plugged in.
    public var canForceDischarge: Bool

    /// The specific SMC key set detected on the host.
    public var activeKeySet: SMCKeySetDescription

    /// Indicates if executing write commands requires an elevated privileged helper daemon.
    public var requiresPrivilege: Bool

    public init(
        canInhibitCharge: Bool,
        canForceDischarge: Bool,
        activeKeySet: SMCKeySetDescription,
        requiresPrivilege: Bool = true
    ) {
        self.canInhibitCharge = canInhibitCharge
        self.canForceDischarge = canForceDischarge
        self.activeKeySet = activeKeySet
        self.requiresPrivilege = requiresPrivilege
    }

    /// Default safe fallback when running in unprivileged user space.
    public static let standardUserSpace = BatteryHardwareCapabilities(
        canInhibitCharge: false,
        canForceDischarge: false,
        activeKeySet: .readOnlyFallback,
        requiresPrivilege: true
    )

    /// Full capability profile for interactive testing and simulation.
    public static let fullCapabilitiesMock = BatteryHardwareCapabilities(
        canInhibitCharge: true,
        canForceDischarge: true,
        activeKeySet: .simulator,
        requiresPrivilege: false
    )
}

/// Defines the strategy used when battery reaches the upper threshold.
public enum SailingStrategy: String, Sendable, Equatable, CaseIterable, Identifiable {
    /// Inhibit charging at upper threshold. Allows natural usage to lower SOC.
    /// Incurs zero additional cycling throughput.
    case passive = "Passive Hysteresis"

    /// Actively commands battery discharge down to the lower threshold.
    /// Accelerates exit from high-SOC dwell at the cost of ~10% cycle throughput per loop.
    case activeDischarge = "Active Discharge"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .passive: return "Passive (0% Cycle Wear)"
        case .activeDischarge: return "Active Discharge"
        }
    }

    public var tradeOffSummary: String {
        switch self {
        case .passive:
            return "No added battery throughput. Relies on natural power shifts; drops slowly if fully powered by adapter."
        case .activeDischarge:
            return "Quickly drops SOC to lower limit, but adds ~10% cycle throughput per cycle."
        }
    }
}

/// The operational phase of the Hysteresis Controller.
public enum HysteresisPhase: String, Sendable, Equatable, CaseIterable {
    /// Feature is disabled or laptop is running on battery.
    case inactive = "Sailing Mode deactivated."

    /// Actively charging until reaching the configured upper limit.
    case chargingUp = "Charging to Upper Limit"

    /// In the hysteresis band with charging inhibited (or active discharge running).
    case sailing = "Sailing in Hysteresis Band"

    /// Holding charge at the target boundary.
    case holding = "Holding Charge"

    public var isSailing: Bool {
        self == .sailing
    }
}

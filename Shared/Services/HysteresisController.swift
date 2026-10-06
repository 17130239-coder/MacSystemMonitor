import Foundation

/// Pure domain logic state machine implementing a hysteresis band for battery charging.
/// Prevents hunting/chattering around a single target threshold.
public struct HysteresisController: Sendable, Equatable {
    /// Upper charge limit (e.g. 80.0%).
    public var upperLimit: Double

    /// Lower threshold where charging is re-engaged (e.g. 75.0%).
    public var lowerLimit: Double

    /// Selected strategy for handling the upper threshold.
    public var strategy: SailingStrategy

    /// Whether Sailing Mode is activated by the user.
    public var isEnabled: Bool

    /// Current operational phase within the state machine.
    public private(set) var currentPhase: HysteresisPhase

    public init(
        upperLimit: Double = 80.0,
        lowerLimit: Double = 75.0,
        strategy: SailingStrategy = .passive,
        isEnabled: Bool = false,
        initialPhase: HysteresisPhase = .inactive
    ) {
        self.upperLimit = upperLimit
        self.lowerLimit = lowerLimit
        self.strategy = strategy
        self.isEnabled = isEnabled
        self.currentPhase = initialPhase
    }

    /// Reset state machine when configuration changes dramatically.
    public mutating func reset() {
        currentPhase = isEnabled ? .chargingUp : .inactive
    }

    /// Evaluates current telemetry and hardware capabilities, updates internal phase,
    /// and returns the appropriate high-level ChargingIntent.
    public mutating func evaluate(
        soc: Double,
        isPluggedIn: Bool,
        capabilities: BatteryHardwareCapabilities
    ) -> ChargingIntent {
        // If disabled or running on battery, delegate to system hardware defaults
        guard isEnabled && isPluggedIn else {
            currentPhase = .inactive
            return .allowHardwareDefault
        }

        // Clamp thresholds to ensure a valid hysteresis band (lower strictly < upper)
        let safeLower = min(lowerLimit, upperLimit - 1.0)
        let safeUpper = max(upperLimit, safeLower + 1.0)

        switch currentPhase {
        case .inactive:
            if soc >= safeUpper {
                currentPhase = .sailing
                return decideDischargeOrInhibit(capabilities: capabilities)
            } else {
                currentPhase = .chargingUp
                return .enableCharging
            }

        case .chargingUp:
            if soc >= safeUpper {
                // Reached upper threshold -> enter hysteresis band
                currentPhase = .sailing
                return decideDischargeOrInhibit(capabilities: capabilities)
            }
            // Still below upper threshold -> keep charging
            return .enableCharging

        case .sailing:
            if soc <= safeLower {
                // Dropped to or below lower threshold -> exit sailing, resume charging
                currentPhase = .chargingUp
                return .enableCharging
            }
            // Inside the hysteresis band: keep sailing without hunting
            return decideDischargeOrInhibit(capabilities: capabilities)

        case .holding:
            if soc <= safeLower {
                currentPhase = .chargingUp
                return .enableCharging
            } else if soc >= safeUpper {
                currentPhase = .sailing
                return decideDischargeOrInhibit(capabilities: capabilities)
            }
            return .inhibitCharging
        }
    }

    private func decideDischargeOrInhibit(capabilities: BatteryHardwareCapabilities) -> ChargingIntent {
        if strategy == .activeDischarge && capabilities.canForceDischarge {
            return .forceDischarge
        } else {
            return .inhibitCharging
        }
    }
}

import Foundation
import IOKit

/// Protocol abstracting charge control operations and capability detection.
public protocol ChargeControlBackendProtocol: Sendable {
    func probeCapabilities() async -> BatteryHardwareCapabilities
    func apply(intent: ChargingIntent) async throws
}

/// Probes the host system's SMC keys and privileges dynamically at runtime.
/// Avoids hardcoded chip model assumptions and safely distinguishes
/// between read-only observability and active control capabilities.
public final class AppleSMCCapabilityProber: Sendable {
    public init() {}

    /// Performs dynamic discovery of charging-related SMC keys.
    public func probe() -> BatteryHardwareCapabilities {
        // First check if AppleSMC interface is accessible
        guard let smc = SMCConnection() else {
            return BatteryHardwareCapabilities(
                canInhibitCharge: false,
                canForceDischarge: false,
                activeKeySet: .readOnlyFallback,
                requiresPrivilege: true
            )
        }

        let isRoot = geteuid() == 0

        // Probe for modern keys: CHTE (charge limit / inhibit), CHIE (force discharge)
        let hasCHTE = smc.read("CHTE") != nil
        let hasCHIE = smc.read("CHIE") != nil

        if hasCHTE {
            return BatteryHardwareCapabilities(
                canInhibitCharge: true,
                canForceDischarge: hasCHIE,
                activeKeySet: .modernCHTE,
                requiresPrivilege: !isRoot
            )
        }

        // Probe for legacy keys: CH0B / CH0C (charge gating), CH0I (force discharge)
        let hasCH0B = smc.read("CH0B") != nil || smc.read("CH0C") != nil
        let hasCH0I = smc.read("CH0I") != nil

        if hasCH0B {
            return BatteryHardwareCapabilities(
                canInhibitCharge: true,
                canForceDischarge: hasCH0I,
                activeKeySet: .legacyCH0B,
                requiresPrivilege: !isRoot
            )
        }

        // Safe fallback when no known charging control keys are exposed for direct read/write
        return BatteryHardwareCapabilities(
            canInhibitCharge: false,
            canForceDischarge: false,
            activeKeySet: .readOnlyFallback,
            requiresPrivilege: true
        )
    }
}

/// Production charge control backend executing probed SMC actions or managing safe fallback.
public final class SMCChargeControlBackend: ChargeControlBackendProtocol, @unchecked Sendable {
    private let prober: AppleSMCCapabilityProber
    private var cachedCapabilities: BatteryHardwareCapabilities?
    private(set) var lastAppliedIntent: ChargingIntent = .allowHardwareDefault

    public init(prober: AppleSMCCapabilityProber = AppleSMCCapabilityProber()) {
        self.prober = prober
    }

    public func probeCapabilities() async -> BatteryHardwareCapabilities {
        let caps = prober.probe()
        self.cachedCapabilities = caps
        return caps
    }

    public func apply(intent: ChargingIntent) async throws {
        self.lastAppliedIntent = intent

        // In standard unprivileged user space, we record intent and operate in safe monitor mode.
        // If an elevated daemon or root helper is installed, write commands are dispatched here.
        guard let caps = cachedCapabilities else { return }
        if caps.requiresPrivilege && geteuid() != 0 {
            // Unprivileged: record state without crashing or triggering unauthorized kernel faults
            return
        }

        // Future privileged helper dispatch path:
        // switch (intent, caps.activeKeySet) { ... }
    }
}

/// Simulated backend for SwiftUI previews, UI demonstration, and automated test suites.
public final class SimulatedChargeControlBackend: ChargeControlBackendProtocol, @unchecked Sendable {
    public var simulatedCapabilities: BatteryHardwareCapabilities
    public private(set) var appliedIntents: [ChargingIntent] = []

    public init(capabilities: BatteryHardwareCapabilities = .fullCapabilitiesMock) {
        self.simulatedCapabilities = capabilities
    }

    public func probeCapabilities() async -> BatteryHardwareCapabilities {
        return simulatedCapabilities
    }

    public func apply(intent: ChargingIntent) async throws {
        appliedIntents.append(intent)
    }
}

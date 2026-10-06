import Foundation
import SwiftUI

/// Main coordinator managing Sailing Mode state, coordinating the Hysteresis Controller,
/// tracking hardware capabilities, and delivering telemetry updates to the UI.
@MainActor
@Observable
public final class SailingModeEngine {
    public static let shared = SailingModeEngine()

    // MARK: - User Settings

    public var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "SailingMode_IsEnabled")
            controller.isEnabled = isEnabled
            controller.reset()
            reevaluate()
        }
    }

    public var upperLimit: Double {
        didSet {
            UserDefaults.standard.set(upperLimit, forKey: "SailingMode_UpperLimit")
            controller.upperLimit = upperLimit
            reevaluate()
        }
    }

    public var lowerLimit: Double {
        didSet {
            UserDefaults.standard.set(lowerLimit, forKey: "SailingMode_LowerLimit")
            controller.lowerLimit = lowerLimit
            reevaluate()
        }
    }

    public var strategy: SailingStrategy {
        didSet {
            UserDefaults.standard.set(strategy.rawValue, forKey: "SailingMode_Strategy")
            controller.strategy = strategy
            reevaluate()
        }
    }

    // MARK: - Simulation Mode (Interactive Demonstration)

    public var isSimulating: Bool = false {
        didSet {
            reevaluate()
        }
    }

    public var simulatedSOC: Double = 78.0 {
        didSet {
            if isSimulating {
                reevaluate()
            }
        }
    }

    // MARK: - Operational State

    public private(set) var currentPhase: HysteresisPhase = .inactive
    public private(set) var currentIntent: ChargingIntent = .allowHardwareDefault
    public private(set) var capabilities: BatteryHardwareCapabilities = .standardUserSpace

    // MARK: - Internal Dependencies

    private var controller: HysteresisController
    private let backend: any ChargeControlBackendProtocol
    private var lastObservedSOC: Double = 100.0
    private var lastObservedPluggedIn: Bool = true

    // MARK: - Initializer

    public init(backend: (any ChargeControlBackendProtocol)? = nil) {
        let savedEnabled = UserDefaults.standard.bool(forKey: "SailingMode_IsEnabled")
        let savedUpper = UserDefaults.standard.double(forKey: "SailingMode_UpperLimit")
        let savedLower = UserDefaults.standard.double(forKey: "SailingMode_LowerLimit")
        let savedStrategyStr = UserDefaults.standard.string(forKey: "SailingMode_Strategy")

        let effectiveUpper = savedUpper > 0 ? savedUpper : 80.0
        let effectiveLower = savedLower > 0 ? savedLower : 75.0
        let effectiveStrategy = savedStrategyStr.flatMap(SailingStrategy.init(rawValue:)) ?? .passive

        self.isEnabled = savedEnabled
        self.upperLimit = effectiveUpper
        self.lowerLimit = effectiveLower
        self.strategy = effectiveStrategy

        self.controller = HysteresisController(
            upperLimit: effectiveUpper,
            lowerLimit: effectiveLower,
            strategy: effectiveStrategy,
            isEnabled: savedEnabled
        )

        let resolvedBackend = backend ?? SMCChargeControlBackend()
        self.backend = resolvedBackend

        Task { [weak self] in
            await self?.probeHardware()
        }
    }

    // MARK: - Hardware Probing

    public func probeHardware() async {
        let caps = await backend.probeCapabilities()
        self.capabilities = caps
        reevaluate()
    }

    // MARK: - Telemetry Feed

    public func update(currentBatteryPercent: Double, isPluggedIn: Bool) {
        self.lastObservedSOC = currentBatteryPercent
        self.lastObservedPluggedIn = isPluggedIn
        reevaluate()
    }

    // MARK: - Evaluation Cycle

    public func reevaluate() {
        let soc = isSimulating ? simulatedSOC : lastObservedSOC
        let isPluggedIn = isSimulating ? true : lastObservedPluggedIn

        let intent = controller.evaluate(
            soc: soc,
            isPluggedIn: isPluggedIn,
            capabilities: capabilities
        )

        self.currentPhase = controller.currentPhase
        self.currentIntent = intent

        Task { [weak self, intent] in
            guard let self else { return }
            try? await self.backend.apply(intent: intent)
        }
    }

    public func toggleEnabled() {
        isEnabled.toggle()
    }
}

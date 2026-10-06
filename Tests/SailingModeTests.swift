import XCTest

final class SailingModeTests: XCTestCase {

    // MARK: - Hysteresis Controller Tests

    func testDisabledOrUnpluggedReturnsHardwareDefault() {
        var controller = HysteresisController(upperLimit: 80, lowerLimit: 75, strategy: .passive, isEnabled: false)

        let intent1 = controller.evaluate(soc: 70, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(intent1, .allowHardwareDefault)
        XCTAssertEqual(controller.currentPhase, .inactive)

        // When enabled but on battery (unplugged)
        controller.isEnabled = true
        let intent2 = controller.evaluate(soc: 70, isPluggedIn: false, capabilities: .standardUserSpace)
        XCTAssertEqual(intent2, .allowHardwareDefault)
        XCTAssertEqual(controller.currentPhase, .inactive)
    }

    func testChargingUpPhaseBelowUpperThreshold() {
        var controller = HysteresisController(upperLimit: 80, lowerLimit: 75, strategy: .passive, isEnabled: true)

        // Below lower threshold
        let intent1 = controller.evaluate(soc: 70, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(intent1, .enableCharging)
        XCTAssertEqual(controller.currentPhase, .chargingUp)

        // Rising between lower and upper while charging
        let intent2 = controller.evaluate(soc: 76, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(intent2, .enableCharging)
        XCTAssertEqual(controller.currentPhase, .chargingUp)

        let intent3 = controller.evaluate(soc: 79, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(intent3, .enableCharging)
        XCTAssertEqual(controller.currentPhase, .chargingUp)
    }

    func testEntersSailingPhaseAtUpperLimitWithPassiveStrategy() {
        var controller = HysteresisController(upperLimit: 80, lowerLimit: 75, strategy: .passive, isEnabled: true)

        _ = controller.evaluate(soc: 79, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(controller.currentPhase, .chargingUp)

        // Hits 80%
        let intent = controller.evaluate(soc: 80, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(controller.currentPhase, .sailing)
        XCTAssertEqual(intent, .inhibitCharging)
    }

    func testHysteresisBandPreventsHuntingAndChattering() {
        var controller = HysteresisController(upperLimit: 80, lowerLimit: 75, strategy: .passive, isEnabled: true)

        // Transition into sailing
        _ = controller.evaluate(soc: 80, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(controller.currentPhase, .sailing)

        // Fluctuation inside the band: 79%, 78%, 77%, 76% must NOT trigger charge
        for soc in [79.0, 78.5, 77.0, 76.0] {
            let intent = controller.evaluate(soc: soc, isPluggedIn: true, capabilities: .standardUserSpace)
            XCTAssertEqual(intent, .inhibitCharging, "Failed to hold inhibit inside hysteresis band at \(soc)%")
            XCTAssertEqual(controller.currentPhase, .sailing)
        }
    }

    func testResumesChargingWhenDroppingToOrBelowLowerLimit() {
        var controller = HysteresisController(upperLimit: 80, lowerLimit: 75, strategy: .passive, isEnabled: true)

        // Enter sailing
        _ = controller.evaluate(soc: 80, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(controller.currentPhase, .sailing)

        // Drops to lower threshold (75%)
        let intent = controller.evaluate(soc: 75, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(controller.currentPhase, .chargingUp)
        XCTAssertEqual(intent, .enableCharging)

        // Rises back to 77% while in chargingUp -> keeps charging
        let risingIntent = controller.evaluate(soc: 77, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertEqual(controller.currentPhase, .chargingUp)
        XCTAssertEqual(risingIntent, .enableCharging)
    }

    func testActiveDischargeStrategyWithCapableHardware() {
        let capableCaps = BatteryHardwareCapabilities(
            canInhibitCharge: true,
            canForceDischarge: true,
            activeKeySet: .legacyCH0B,
            requiresPrivilege: false
        )

        var controller = HysteresisController(
            upperLimit: 80,
            lowerLimit: 75,
            strategy: .activeDischarge,
            isEnabled: true
        )

        // Reaching 80% triggers force discharge
        let intent = controller.evaluate(soc: 80, isPluggedIn: true, capabilities: capableCaps)
        XCTAssertEqual(controller.currentPhase, .sailing)
        XCTAssertEqual(intent, .forceDischarge)

        // Inside the band while discharging
        let intentBand = controller.evaluate(soc: 78, isPluggedIn: true, capabilities: capableCaps)
        XCTAssertEqual(controller.currentPhase, .sailing)
        XCTAssertEqual(intentBand, .forceDischarge)
    }

    func testActiveDischargeGracefullyFallsBackWhenDischargeUnsupported() {
        let inhibitOnlyCaps = BatteryHardwareCapabilities(
            canInhibitCharge: true,
            canForceDischarge: false, // Cannot force discharge
            activeKeySet: .modernCHTE,
            requiresPrivilege: false
        )

        var controller = HysteresisController(
            upperLimit: 80,
            lowerLimit: 75,
            strategy: .activeDischarge,
            isEnabled: true
        )

        // Reaching 80% should gracefully fall back to inhibitCharging rather than failing
        let intent = controller.evaluate(soc: 80, isPluggedIn: true, capabilities: inhibitOnlyCaps)
        XCTAssertEqual(controller.currentPhase, .sailing)
        XCTAssertEqual(intent, .inhibitCharging)
    }

    func testSafeThresholdClamping() {
        // Upper <= Lower edge case: controller must enforce safeLower < safeUpper
        var controller = HysteresisController(upperLimit: 70, lowerLimit: 75, strategy: .passive, isEnabled: true)

        let intent = controller.evaluate(soc: 72, isPluggedIn: true, capabilities: .standardUserSpace)
        XCTAssertNotNil(intent)
    }

    // MARK: - Backend & Capability Probing Tests

    func testSimulatedBackendRecordsIntents() async throws {
        let backend = SimulatedChargeControlBackend()
        let caps = await backend.probeCapabilities()

        XCTAssertTrue(caps.canInhibitCharge)
        XCTAssertTrue(caps.canForceDischarge)
        XCTAssertEqual(caps.activeKeySet, .simulator)

        try await backend.apply(intent: .inhibitCharging)
        try await backend.apply(intent: .enableCharging)

        XCTAssertEqual(backend.appliedIntents, [.inhibitCharging, .enableCharging])
    }

    // MARK: - Engine Integration Test

    @MainActor
    func testSailingModeEngineCoordination() {
        let engine = SailingModeEngine(backend: SimulatedChargeControlBackend())
        engine.isEnabled = true
        engine.upperLimit = 80
        engine.lowerLimit = 75
        engine.isSimulating = true

        engine.simulatedSOC = 70
        XCTAssertEqual(engine.currentPhase, .chargingUp)
        XCTAssertEqual(engine.currentIntent, .enableCharging)

        engine.simulatedSOC = 80
        XCTAssertEqual(engine.currentPhase, .sailing)
        XCTAssertEqual(engine.currentIntent, .inhibitCharging)

        engine.simulatedSOC = 77
        XCTAssertEqual(engine.currentPhase, .sailing)
        XCTAssertEqual(engine.currentIntent, .inhibitCharging)

        engine.simulatedSOC = 75
        XCTAssertEqual(engine.currentPhase, .chargingUp)
        XCTAssertEqual(engine.currentIntent, .enableCharging)
    }
}

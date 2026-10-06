import XCTest

final class FanTests: XCTestCase {
    private func smc(count: UInt8?, rpm: [String: Float] = [:]) -> MockSMC {
        var v: [String: SMCValue] = [:]
        if let count { v["FNum"] = MockSMC.uint8("FNum", count) }
        for (k, r) in rpm { v[k] = MockSMC.float(k, r) }
        return MockSMC(v)
    }

    private func metrics(_ fan: FanMetrics) -> SystemMetrics {
        var m = SystemMetrics.empty
        m.fan = fan
        return m
    }

    func testFanlessWhenSMCReportsZeroFans() {
        let f = FanService(smc: smc(count: 0), modelIdentifier: "Mac14,2", modelName: "MacBook Air").sample()
        XCTAssertEqual(f.presence, .fanless)
        XCTAssertEqual(metrics(f).fanValueText, "Fanless")
        XCTAssertNil(metrics(f).fanCaptionText, "must not show 'RPM' for a fanless Mac")
    }

    func testFanlessMacNeverShowsZeroRPM() {
        let f = FanService(smc: smc(count: 0), modelIdentifier: "x", modelName: "Mac").sample()
        XCTAssertNotEqual(metrics(f).fanValueText, "0")
    }

    func testAirWithInaccessibleSMCIsStillFanless() {
        let f = FanService(smc: nil, modelIdentifier: "MacBookAir10,1", modelName: "MacBook Air").sample()
        XCTAssertEqual(f.presence, .fanless)
    }

    func testProWithInaccessibleSMCIsUnknownAndShowsNA() {
        let f = FanService(smc: nil, modelIdentifier: "MacBookPro18,1", modelName: "MacBook Pro").sample()
        XCTAssertEqual(f.presence, .unknown)
        XCTAssertFalse(f.rpm.isAvailable)
        XCTAssertEqual(metrics(f).fanValueText, "N/A")
    }

    func testRPMIsMeanOfAllFans() {
        let s = smc(count: 2, rpm: ["F0Ac": 1800, "F1Ac": 2000])
        let f = FanService(smc: s, modelIdentifier: "MacBookPro18,1", modelName: "MacBook Pro").sample()
        XCTAssertEqual(f.presence, .present)
        XCTAssertEqual(f.fanCount, 2)
        XCTAssertEqual(f.rpm.value!, 1900, accuracy: 0.0001)
        XCTAssertEqual(metrics(f).fanValueText, "1900")
        XCTAssertEqual(metrics(f).fanCaptionText, "RPM")
    }

    func testIndividualFansRecordedWhenMultipleFansPresent() {
        var values: [String: SMCValue] = [
            "FNum": MockSMC.uint8("FNum", 2),
            "F0Ac": MockSMC.float("F0Ac", 1512),
            "F1Ac": MockSMC.float("F1Ac", 1645),
            "F0Mn": MockSMC.float("F0Mn", 1499),
            "F1Mn": MockSMC.float("F1Mn", 1499),
            "F0Mx": MockSMC.float("F0Mx", 4296),
            "F1Mx": MockSMC.float("F1Mx", 4744),
        ]
        let s = MockSMC(values)
        let f = FanService(smc: s, modelIdentifier: "MacBookPro18,1", modelName: "MacBook Pro").sample()
        XCTAssertEqual(f.fans?.count, 2)
        XCTAssertEqual(f.fans?[0].label, "Left")
        XCTAssertEqual(f.fans?[0].rpm, 1512)
        XCTAssertEqual(f.fans?[0].minRPM, 1499)
        XCTAssertEqual(f.fans?[0].maxRPM, 4296)
        XCTAssertEqual(f.fans?[1].label, "Right")
        XCTAssertEqual(f.fans?[1].rpm, 1645)
        XCTAssertEqual(f.fans?[1].minRPM, 1499)
        XCTAssertEqual(f.fans?[1].maxRPM, 4744)
    }

    func testStoppedFanOnMacWithFanIsZeroRPMNotFanless() {
        let s = smc(count: 1, rpm: ["F0Ac": 0])
        let f = FanService(smc: s, modelIdentifier: "MacBookPro18,1", modelName: "MacBook Pro").sample()
        XCTAssertEqual(f.presence, .present)
        XCTAssertEqual(metrics(f).fanValueText, "0")
    }

    func testFanPresentButRPMKeyUnreadable() {
        let f = FanService(smc: smc(count: 1), modelIdentifier: "MacBookPro18,1", modelName: "MacBook Pro").sample()
        XCTAssertEqual(f.presence, .present)
        XCTAssertEqual(metrics(f).fanValueText, "N/A")
    }

    func testSMCWithoutFNumOnUnknownModel() {
        let f = FanService(smc: smc(count: nil), modelIdentifier: "Mac99,1", modelName: "Mac").sample()
        XCTAssertEqual(f.presence, .unknown)
    }
}

final class BatteryTests: XCTestCase {
    func testNoBatteryMeansNAEverywhere() {
        let b = BatteryService(source: MockBattery(reading: nil)).sample(sensorTemperature: .available(34))
        XCTAssertEqual(b, .notPresent)
        var m = SystemMetrics.empty
        m.battery = b
        XCTAssertEqual(m.batteryPercentText, "N/A")
        XCTAssertEqual(m.batteryTemperatureText, "N/A")
        XCTAssertNil(m.batteryStateText)
    }

    func testPercentAndSensorTemperatureFallback() {
        let r = BatteryReading(percent: 85.6, isCharging: false, isOnACPower: false, registryTemperatureCelsius: nil)
        let b = BatteryService(source: MockBattery(reading: r)).sample(sensorTemperature: .available(34.2))
        var m = SystemMetrics.empty
        m.battery = b
        XCTAssertEqual(m.batteryPercentText, "86%")
        XCTAssertEqual(m.batteryTemperatureText, "34°C")
        XCTAssertEqual(b.chargingState, .discharging)
    }

    func testRegistryTemperatureWinsOverSensor() {
        let r = BatteryReading(percent: 50, isCharging: false, isOnACPower: true, registryTemperatureCelsius: 30)
        let b = BatteryService(source: MockBattery(reading: r)).sample(sensorTemperature: .available(40))
        XCTAssertEqual(b.temperature.value, 30)
        XCTAssertEqual(b.chargingState, .pluggedIn)
    }

    func testBatteryPresentButTemperatureUnavailable() {
        let r = BatteryReading(percent: 70, isCharging: true, isOnACPower: true, registryTemperatureCelsius: nil)
        let b = BatteryService(source: MockBattery(reading: r)).sample(sensorTemperature: .unavailable("none"))
        var m = SystemMetrics.empty
        m.battery = b
        XCTAssertEqual(m.batteryPercentText, "70%")
        XCTAssertEqual(m.batteryTemperatureText, "N/A")
        XCTAssertEqual(m.batteryStateText, "Charging")
    }
}

final class StatusTests: XCTestCase {
    private func evaluator(smoothing: Double = 1) -> StatusEvaluator { StatusEvaluator(smoothing: smoothing) }

    func testNormalWarmHot() {
        var e = evaluator()
        XCTAssertEqual(e.update([.cpu: 50]), .normal)
        XCTAssertEqual(e.update([.cpu: 80]), .warm)
        XCTAssertEqual(e.update([.cpu: 95]), .hot)
    }

    func testPerSensorThresholdsDiffer() {
        var e = evaluator()
        XCTAssertEqual(e.update([.cpu: 50, .battery: 46]), .hot, "46 °C is hot for a battery")
    }

    func testWorstSensorWins() {
        var e = evaluator()
        XCTAssertEqual(e.update([.cpu: 40, .gpu: 78, .ssd: 30]), .warm)
    }

    func testSingleSpikeDoesNotTriggerHot() {
        var e = evaluator(smoothing: 0.25)
        for _ in 0 ..< 10 { XCTAssertEqual(e.update([.cpu: 50]), .normal) }
        XCTAssertNotEqual(e.update([.cpu: 100]), .hot)     // 50 + 0.25 * 50 = 62.5
        XCTAssertEqual(e.update([.cpu: 50]), .normal)
    }

    func testSustainedHeatEventuallyEscalates() {
        var e = evaluator(smoothing: 0.25)
        var status = SystemStatus.normal
        for _ in 0 ..< 30 { status = e.update([.cpu: 100]) }
        XCTAssertEqual(status, .hot)
    }

    func testHysteresisPreventsFlapping() {
        var e = evaluator()
        XCTAssertEqual(e.update([.cpu: 76]), .warm)
        XCTAssertEqual(e.update([.cpu: 74]), .warm, "just below the threshold: still warm")
        XCTAssertEqual(e.update([.cpu: 73]), .warm)
        XCTAssertEqual(e.update([.cpu: 71]), .normal, "3 °C below threshold: back to normal")
    }

    func testHotDeescalatesToWarmThenNormal() {
        var e = evaluator()
        XCTAssertEqual(e.update([.cpu: 95]), .hot)
        XCTAssertEqual(e.update([.cpu: 88]), .hot)
        XCTAssertEqual(e.update([.cpu: 80]), .warm)
        XCTAssertEqual(e.update([.cpu: 60]), .normal)
    }

    func testUnknownWhenNoTemperatureAvailable() {
        var e = evaluator()
        XCTAssertEqual(e.update([.cpu: nil, .gpu: nil]), .unknown)
        XCTAssertEqual(SystemStatus.unknown.label, "N/A")
    }

    func testLabels() {
        XCTAssertEqual(SystemStatus.normal.label, "Normal")
        XCTAssertEqual(SystemStatus.warm.label, "Warm")
        XCTAssertEqual(SystemStatus.hot.label, "Hot")
    }
}

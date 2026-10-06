import XCTest

final class SamplerTests: XCTestCase {
    func testFullMockSensorSet() {
        let m = Fixtures.sampler().sample()
        XCTAssertEqual(m.cpuDisplay.text, "24%")
        XCTAssertEqual(m.cpuDisplay.fraction, 0.24)
        XCTAssertEqual(m.gpuDisplay.text, "12%")
        XCTAssertEqual(m.memoryDisplay.text, "48%")                          // (400k+100k) pages * 16 KiB = 7.63 GiB of 16
        XCTAssertEqual(m.memoryDisplay.detail, "7.6 / 16 GB")
        XCTAssertEqual(m.cpuTemperatureText, "58°C")
        XCTAssertEqual(m.gpuTemperatureText, "52°C")
        XCTAssertEqual(m.batteryPercentText, "86%")
        XCTAssertEqual(m.batteryTemperatureText, "34°C")
        XCTAssertEqual(m.ssdTemperatureText, "41°C")
        XCTAssertEqual(m.fanValueText, "1900")
        XCTAssertEqual(m.status, .normal)
    }

    /// The "acceptable" example from the spec: several sensors missing, everything else still works.
    func testPartialSensorsOnFanlessAir() {
        let probes: [TemperatureProbe] = [MockProbe(source: "SMC", ["Tp01": 58])]
        let m = Fixtures.sampler(probes: probes, smc: MockSMC([ "FNum": MockSMC.uint8("FNum", 0)]),
                                 modelName: "MacBook Air").sample()
        XCTAssertEqual(m.cpuDisplay.text, "24%")
        XCTAssertEqual(m.cpuTemperatureText, "58°C")
        XCTAssertEqual(m.gpuDisplay.text, "12%")
        XCTAssertEqual(m.gpuTemperatureText, "N/A")
        XCTAssertEqual(m.batteryPercentText, "86%")
        XCTAssertEqual(m.batteryTemperatureText, "N/A")
        XCTAssertEqual(m.ssdTemperatureText, "N/A")
        XCTAssertEqual(m.fanValueText, "Fanless")
    }

    func testEverythingFailingNeverCrashes() {
        let m = Fixtures.sampler(probes: [], smc: nil, battery: nil, gpu: nil,
                                 cpuTicks: [nil], memory: nil).sample()
        XCTAssertEqual(m.cpuDisplay.text, "N/A")
        XCTAssertEqual(m.gpuDisplay.text, "N/A")
        XCTAssertEqual(m.memoryDisplay.text, "N/A")
        XCTAssertEqual(m.cpuTemperatureText, "N/A")
        XCTAssertEqual(m.batteryPercentText, "N/A")
        XCTAssertEqual(m.ssdTemperatureText, "N/A")
        XCTAssertEqual(m.fanValueText, "N/A")
        XCTAssertEqual(m.status, .unknown)
    }

    func testMacWithoutBattery() {
        let m = Fixtures.sampler(battery: nil).sample()
        XCTAssertEqual(m.battery.percent.availability, .unsupported)
        XCTAssertEqual(m.batteryPercentText, "N/A")
        XCTAssertEqual(m.batteryTemperatureText, "N/A")
        XCTAssertEqual(m.cpuDisplay.text, "24%", "other metrics are unaffected")
    }

    func testMetricsEqualityIgnoresTimestamp() {
        let s = Fixtures.sampler()
        let a = s.sample(at: Date(timeIntervalSince1970: 0))
        var b = a
        b.timestamp = Date()
        XCTAssertEqual(a, b)
    }
}

final class FormattingAndModelTests: XCTestCase {
    func testPercentIsIntegerAndBarMatchesText() {
        for value in [0.0, 0.4, 0.5, 23.5, 24.49, 99.5, 100, 250, -5] {
            let text = PercentFormatter.string(value)
            let fraction = PercentFormatter.fraction(value)
            XCTAssertEqual(text, "\(Int((fraction * 100).rounded()))%")
        }
        XCTAssertEqual(PercentFormatter.string(100), "100%")
        XCTAssertEqual(PercentFormatter.string(23.5), "24%")
    }

    func testSensorValueStates() {
        XCTAssertTrue(SensorValue<Double>.available(1).isAvailable)
        for v: SensorValue<Double> in [.unavailable("x"), .unsupported("x"), .permissionDenied("x"), .error("x")] {
            XCTAssertFalse(v.isAvailable)
            XCTAssertNil(v.value)
        }
    }

    func testSnapshotRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("snapshot-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Fixtures.sampler().sample()
        XCTAssertTrue(SnapshotStore.save(original, to: url))
        let loaded = try XCTUnwrap(SnapshotStore.load(from: url))
        XCTAssertEqual(loaded, original)
        // ISO-8601 snapshot timestamps have one-second precision.
        XCTAssertEqual(loaded.timestamp.timeIntervalSince1970, original.timestamp.timeIntervalSince1970, accuracy: 1.0)
    }

    func testSnapshotMissingFileIsNil() {
        XCTAssertNil(SnapshotStore.load(from: nil))
        XCTAssertNil(SnapshotStore.load(from: URL(fileURLWithPath: "/nonexistent/x.json")))
    }

    func testModelNames() {
        XCTAssertEqual(HardwareInfoService.modelName(identifier: "MacBookPro18,1", hasBattery: true), "MacBook Pro")
        XCTAssertEqual(HardwareInfoService.modelName(identifier: "MacBookAir10,1", hasBattery: true), "MacBook Air")
        XCTAssertEqual(HardwareInfoService.modelName(identifier: "Mac14,2", hasBattery: true), "MacBook Air")
        XCTAssertEqual(HardwareInfoService.modelName(identifier: "Mac16,10", hasBattery: false), "Mac mini")
        XCTAssertEqual(HardwareInfoService.modelName(identifier: "Mac99,9", hasBattery: true), "MacBook")
        XCTAssertEqual(HardwareInfoService.modelName(identifier: "Mac99,9", hasBattery: false), "Mac")
    }

    func testHeaderTitleIsBuiltFromDetectedValues() {
        var h = HardwareInfo.unknown
        h.modelName = "MacBook Pro"
        h.chipName = "Apple M1 Pro"
        XCTAssertEqual(h.headerTitle, "MacBook Pro · Apple M1 Pro")
    }

    func testRealHardwareDetectionDoesNotCrash() {
        let h = HardwareInfoService.detect(smc: nil, sensors: [])
        XCTAssertFalse(h.chipName.isEmpty)
        XCTAssertEqual(h.physicalMemoryBytes, ProcessInfo.processInfo.physicalMemory)
    }
}

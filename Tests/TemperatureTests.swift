import XCTest

final class TemperatureTests: XCTestCase {
    // MARK: conversion + formatting

    func testRoundsToWholeDegrees() {
        XCTAssertEqual(TemperatureFormatter.string(celsius: 58.734), "59°C")
        XCTAssertEqual(TemperatureFormatter.string(celsius: 52.2), "52°C")
        XCTAssertEqual(TemperatureFormatter.string(celsius: 41), "41°C")
        XCTAssertEqual(TemperatureFormatter.string(celsius: nil), "N/A")
        XCTAssertEqual(TemperatureFormatter.string(celsius: .nan), "N/A")
    }

    func testConversions() {
        XCTAssertEqual(TemperatureFormatter.celsius(fromCentiDegrees: 3290), 32.9, accuracy: 0.0001)
        XCTAssertEqual(TemperatureFormatter.celsius(fromSP78: 0x3A, 0x80), 58.5, accuracy: 0.0001)
        XCTAssertEqual(TemperatureFormatter.celsius(fromSP78: 0xFF, 0x00), -1.0, accuracy: 0.0001)
        XCTAssertEqual(TemperatureFormatter.celsius(fromKelvin: 300), 26.85, accuracy: 0.0001)
    }

    func testSMCFloatDecoding() {
        XCTAssertEqual(MockSMC.float("Tg05", 52.5).number!, 52.5, accuracy: 0.0001)
        XCTAssertNil(SMCValue(key: "XXXX", type: "hex_", bytes: [1, 2]).number)
        XCTAssertNil(SMCValue(key: "Tg05", type: "flt ", bytes: [1]).number)
    }

    func testPlausibility() {
        XCTAssertFalse(TemperatureFormatter.isPlausible(0))
        XCTAssertFalse(TemperatureFormatter.isPlausible(-40))
        XCTAssertFalse(TemperatureFormatter.isPlausible(500))
        XCTAssertFalse(TemperatureFormatter.isPlausible(.infinity))
        XCTAssertTrue(TemperatureFormatter.isPlausible(42))
    }

    // MARK: classification

    func testClassifier() {
        XCTAssertEqual(SensorClassifier.classify(source: "SMC", name: "Tp09")?.category, .cpu)
        XCTAssertEqual(SensorClassifier.classify(source: "SMC", name: "Te05")?.category, .cpu)
        XCTAssertEqual(SensorClassifier.classify(source: "SMC", name: "Tg0D")?.category, .gpu)
        XCTAssertEqual(SensorClassifier.classify(source: "SMC", name: "TB0T")?.category, .battery)
        XCTAssertEqual(SensorClassifier.classify(source: "SMC", name: "TH0a")?.category, .ssd)
        XCTAssertEqual(SensorClassifier.classify(source: "HID", name: "PMU tdie3")?.category, .cpu)
        XCTAssertEqual(SensorClassifier.classify(source: "HID", name: "gas gauge battery")?.category, .battery)
        XCTAssertEqual(SensorClassifier.classify(source: "HID", name: "NAND CH0 temp")?.category, .ssd)
        XCTAssertNil(SensorClassifier.classify(source: "SMC", name: "TaLP"))
        XCTAssertNil(SensorClassifier.classify(source: "HID", name: "PMU tcal"))
    }

    // MARK: discovery + aggregation

    private func service(_ probes: [TemperatureProbe]) -> TemperatureService {
        TemperatureService(probes: probes, sensors: SensorDiscoveryService.discover(probes: probes))
    }

    func testAllSensorsAvailable() {
        let r = service(Fixtures.fullProbes()).read()
        XCTAssertEqual(r.cpu.value!, (60 + 64 + 50) / 3.0, accuracy: 0.0001, "SMC Tp/Te preferred over HID tdie, averaged")
        XCTAssertEqual(r.gpu.value!, 52, accuracy: 0.0001)
        XCTAssertEqual(r.battery.value!, 34, accuracy: 0.0001, "HID gauge preferred over SMC TB0T")
        XCTAssertEqual(r.ssd.value!, 41, accuracy: 0.0001, "HID NAND preferred over SMC TH0")
    }

    func testSSDUnavailableDoesNotAffectOthers() {
        let probes: [TemperatureProbe] = [
            MockProbe(source: "SMC", ["Tp01": 60, "Tg05": 52]),
            MockProbe(source: "HID", ["gas gauge battery": 34]),
        ]
        let r = service(probes).read()
        XCTAssertFalse(r.ssd.isAvailable)
        XCTAssertEqual(r.ssd.availability, .unavailable)
        XCTAssertEqual(TemperatureFormatter.string(r.ssd), "N/A")
        XCTAssertTrue(r.cpu.isAvailable)
        XCTAssertTrue(r.gpu.isAvailable)
        XCTAssertTrue(r.battery.isAvailable)
    }

    func testFallsBackToHIDWhenSMCHasNoCPUKeys() {
        let probes: [TemperatureProbe] = [MockProbe(source: "HID", ["PMU tdie1": 40, "PMU tdie2": 44])]
        XCTAssertEqual(service(probes).read().cpu.value!, 42, accuracy: 0.0001)
    }

    func testNoInterfacesAtAll() {
        let r = service([]).read()
        for v in [r.cpu, r.gpu, r.battery, r.ssd] {
            XCTAssertEqual(v.availability, .unavailable)
            XCTAssertNil(v.value)
            XCTAssertNotNil(v.detail)
        }
    }

    func testZeroReadingsAreIgnoredAtDiscovery() {
        let probes: [TemperatureProbe] = [MockProbe(source: "SMC", ["TH0a": 0, "TH0b": 37])]
        let found = SensorDiscoveryService.discover(probes: probes)
        XCTAssertEqual(found.map(\.sensor.name), ["TH0b"])
    }

    func testSensorThatStopsRespondingBecomesErrorNotCrash() {
        let probe = MockProbe(source: "HID", ["NAND CH0 temp": 41])
        let svc = service([probe])
        probe.values["NAND CH0 temp"] = .some(nil)
        let ssd = svc.read().ssd
        XCTAssertEqual(ssd.availability, .error)
        XCTAssertEqual(TemperatureFormatter.string(ssd), "N/A")
    }

    func testSSDUsesHottestChannel() {
        let probes: [TemperatureProbe] = [MockProbe(source: "HID", ["NAND CH0 temp": 38, "NAND CH1 temp": 44])]
        XCTAssertEqual(service(probes).read().ssd.value!, 44, accuracy: 0.0001)
    }
}

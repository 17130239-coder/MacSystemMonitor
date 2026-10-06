import Foundation
import XCTest

// Test doubles. None of these touch real hardware, so the whole suite runs anywhere.

final class MockSMC: SMCReading {
    private var values: [String: SMCValue]
    private var order: [String]
    init(_ values: [String: SMCValue] = [:]) {
        self.values = values
        self.order = values.keys.sorted()
    }
    func keyCount() -> Int? { order.count }
    func key(at index: Int) -> String? { order.indices.contains(index) ? order[index] : nil }
    func read(_ key: String) -> SMCValue? { values[key] }

    static func float(_ key: String, _ value: Float) -> SMCValue {
        let bits = value.bitPattern
        return SMCValue(key: key, type: "flt ", bytes: [UInt8(bits & 0xFF), UInt8(bits >> 8 & 0xFF), UInt8(bits >> 16 & 0xFF), UInt8(bits >> 24 & 0xFF)])
    }
    static func uint8(_ key: String, _ value: UInt8) -> SMCValue {
        SMCValue(key: key, type: "ui8 ", bytes: [value])
    }
}

final class MockProbe: TemperatureProbe {
    let sourceName: String
    var values: [String: Double?]
    init(source: String, _ values: [String: Double?]) {
        self.sourceName = source
        self.values = values
    }
    func listSensors() -> [RawSensor] {
        values.keys.sorted().enumerated().map { RawSensor(id: $0.offset, name: $0.element) }
    }
    func readCelsius(_ sensor: RawSensor) -> Double? {
        values[sensor.name] ?? nil
    }
}

struct MockBattery: BatterySource {
    var reading: BatteryReading?
    func read() -> BatteryReading? { reading }
}

struct MockGPU: GPUStatsSource {
    var value: Double?
    func readUtilization() -> Double? { value }
}

struct MockVM: VMStatisticsSource {
    var stats: VMStatistics?
    func read() -> VMStatistics? { stats }
}

final class MockCPUSource: CPUTickSource {
    var queue: [CPUTicks?]
    init(_ queue: [CPUTicks?]) { self.queue = queue }
    func readTicks() -> CPUTicks? { queue.isEmpty ? nil : queue.removeFirst() }
}

enum Fixtures {
    static let gib: UInt64 = 1 << 30

    /// An M1-Pro-like probe set: SMC (CPU/GPU/battery) + HID (NAND, gauge).
    static func fullProbes() -> [TemperatureProbe] {
        [
            MockProbe(source: "SMC", ["Tp01": 60, "Tp02": 64, "Te00": 50, "Tg05": 52, "TB0T": 33, "TH0a": 38]),
            MockProbe(source: "HID", ["PMU tdie1": 42, "gas gauge battery": 34, "NAND CH0 temp": 41]),
        ]
    }

    static func sampler(
        probes: [TemperatureProbe] = fullProbes(),
        smc: SMCReading? = MockSMC([
            "FNum": MockSMC.uint8("FNum", 2),
            "F0Ac": MockSMC.float("F0Ac", 1800), "F1Ac": MockSMC.float("F1Ac", 2000),
        ]),
        modelName: String = "MacBook Pro",
        battery: BatteryReading? = BatteryReading(percent: 86, isCharging: false, isOnACPower: false, registryTemperatureCelsius: nil),
        gpu: Double? = 12,
        cpuTicks: [CPUTicks?] = [
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
            CPUTicks(user: 20, system: 4, idle: 76, nice: 0),
        ],
        memory: VMStatistics? = VMStatistics(internalPages: 400_000, purgeablePages: 0, wiredPages: 100_000, compressedPages: 0, pageSize: 16384)
    ) -> SystemSampler {
        let sensors = SensorDiscoveryService.discover(probes: probes)
        let hardware = HardwareInfo(modelIdentifier: "Test1,1", modelName: modelName, chipName: "Apple M1",
                                    physicalMemoryBytes: 16 * gib, hasBattery: battery != nil,
                                    hasFan: nil, fanCount: 0,
                                    discoveredSensors: SensorDiscoveryService.summaries(of: sensors))
        return SystemSampler(parts: .init(
            hardware: hardware,
            cpu: CPUService(source: MockCPUSource(cpuTicks), smoothing: 1),
            memory: MemoryService(source: MockVM(stats: memory), totalBytes: 16 * gib),
            gpu: GPUService(source: MockGPU(value: gpu)),
            battery: BatteryService(source: MockBattery(reading: battery)),
            temperature: TemperatureService(probes: probes, sensors: sensors),
            fan: FanService(smc: smc, modelIdentifier: "Test1,1", modelName: modelName)
        ))
    }
}

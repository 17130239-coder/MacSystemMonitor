import Foundation

/// Combines all services into one `SystemMetrics` value.
///
/// Not thread-safe by design: it owns stateful services (CPU baseline, status
/// smoothing, SMC connection) and is confined to one executor — `SamplingEngine`
/// in production, the test's own thread in unit tests.
final class SystemSampler {
    struct Parts {
        var hardware: HardwareInfo
        var cpu: CPUService
        var memory: MemoryService
        var gpu: GPUService
        var battery: BatteryService
        var temperature: TemperatureService
        var fan: FanService
        var status: StatusEvaluator = StatusEvaluator()
    }

    private var parts: Parts

    init(parts: Parts) { self.parts = parts }

    /// Builds the production sampler: opens the real sensor interfaces and runs discovery.
    /// Any interface that cannot be opened is simply absent; its metrics become `N/A`.
    static func live() -> SystemSampler {
        let smc = SMCConnection()
        var probes: [TemperatureProbe] = []
        if let smc { probes.append(SMCTemperatureProbe(smc: smc)) }
        if let hid = HIDTemperatureProbe() { probes.append(hid) }

        let sensors = SensorDiscoveryService.discover(probes: probes)
        let hardware = HardwareInfoService.detect(smc: smc, sensors: sensors)

        return SystemSampler(parts: Parts(
            hardware: hardware,
            cpu: CPUService(),
            memory: MemoryService(),
            gpu: GPUService(),
            battery: BatteryService(smc: smc),
            temperature: TemperatureService(probes: probes, sensors: sensors),
            fan: FanService(smc: smc, modelIdentifier: hardware.modelIdentifier, modelName: hardware.modelName)
        ))
    }

    func sample(at date: Date = Date()) -> SystemMetrics {
        let temperatures = parts.temperature.read()
        let battery = parts.battery.sample(sensorTemperature: temperatures.battery)

        let status = parts.status.update([
            .cpu: temperatures.cpu.value,
            .gpu: temperatures.gpu.value,
            .battery: battery.temperature.value,
            .ssd: temperatures.ssd.value,
        ])

        return SystemMetrics(
            hardware: parts.hardware,
            cpuUsage: parts.cpu.sample(),
            cpuTemperature: temperatures.cpu,
            gpuUsage: parts.gpu.sample(),
            gpuTemperature: temperatures.gpu,
            memory: parts.memory.sample(),
            battery: battery,
            ssdTemperature: temperatures.ssd,
            fan: parts.fan.sample(),
            status: status,
            timestamp: date
        )
    }
}

/// Runs the sampler off the main thread.
actor SamplingEngine {
    private let sampler: SystemSampler
    private var warmedUp = false

    init(makeSampler: @Sendable () -> SystemSampler) {
        self.sampler = makeSampler()
    }

    func sample() async -> SystemMetrics {
        if !warmedUp {
            // CPU usage is a delta between two snapshots; give the baseline taken at
            // creation a moment to accumulate so the very first frame is not "N/A".
            warmedUp = true
            try? await Task.sleep(for: .milliseconds(400))
        }
        return sampler.sample()
    }
}

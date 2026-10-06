import Foundation
import IOKit
import IOKit.ps

struct BatteryReading: Equatable, Sendable {
    /// 0...100
    var percent: Double
    var isCharging: Bool
    var isOnACPower: Bool
    /// From the AppleSmartBattery registry entry, if that key exists on this Mac / OS.
    var registryTemperatureCelsius: Double? = nil
    var batteryVoltageVolts: Double? = nil
    var batteryAmperageAmps: Double? = nil
    var adapterRatedWatts: Double? = nil
    var adapterRatedVoltageVolts: Double? = nil
    var adapterRatedCurrentAmps: Double? = nil
    var adapterDescription: String? = nil
}

protocol BatterySource {
    /// nil = this Mac has no internal battery.
    func read() -> BatteryReading?
}

/// Battery % and charging state: public `IOPowerSources` API (what the menu bar uses).
/// Temperature, voltage, amperage & adapter details: `AppleSmartBattery` IORegistry.
struct IOKitBatterySource: BatterySource {
    func read() -> BatteryReading? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else { return nil }

        for source in list {
            guard let description = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  (description[kIOPSIsPresentKey] as? Bool ?? true) else { continue }

            guard let current = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue,
                  let maximum = (description[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue, maximum > 0 else {
                continue
            }
            let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            let onAC = (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            let smartProps = Self.smartBatteryProperties()

            return BatteryReading(
                percent: min(100, max(0, current / maximum * 100)),
                isCharging: isCharging,
                isOnACPower: onAC,
                registryTemperatureCelsius: smartProps.temperature,
                batteryVoltageVolts: smartProps.voltageVolts,
                batteryAmperageAmps: smartProps.amperageAmps,
                adapterRatedWatts: smartProps.adapterWatts,
                adapterRatedVoltageVolts: smartProps.adapterVoltage,
                adapterRatedCurrentAmps: smartProps.adapterCurrent,
                adapterDescription: smartProps.adapterDescription
            )
        }
        return nil
    }

    private struct SmartBatteryDetails {
        var temperature: Double?
        var voltageVolts: Double?
        var amperageAmps: Double?
        var adapterWatts: Double?
        var adapterVoltage: Double?
        var adapterCurrent: Double?
        var adapterDescription: String?
    }

    private static func smartBatteryProperties() -> SmartBatteryDetails {
        var details = SmartBatteryDetails()
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return details }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return details }

        if let rawTemp = dict["Temperature"] as? NSNumber {
            let celsius = TemperatureFormatter.celsius(fromCentiDegrees: rawTemp.intValue)
            if TemperatureFormatter.isPlausible(celsius) { details.temperature = celsius }
        }

        if let voltMV = (dict["Voltage"] as? NSNumber)?.doubleValue {
            details.voltageVolts = voltMV / 1000.0
        }

        if let ampMA = (dict["Amperage"] as? NSNumber)?.doubleValue {
            details.amperageAmps = ampMA / 1000.0
        }

        if let adapter = dict["AdapterDetails"] as? [String: Any] {
            if let w = (adapter["Watts"] as? NSNumber)?.doubleValue { details.adapterWatts = w }
            if let vMV = (adapter["AdapterVoltage"] as? NSNumber)?.doubleValue { details.adapterVoltage = vMV / 1000.0 }
            if let cMA = (adapter["Current"] as? NSNumber)?.doubleValue { details.adapterCurrent = cMA / 1000.0 }
            if let desc = adapter["Description"] as? String { details.adapterDescription = desc }
        }

        return details
    }
}

final class BatteryService {
    private let source: BatterySource
    private weak var smc: SMCReading?

    init(source: BatterySource = IOKitBatterySource(), smc: SMCReading? = nil) {
        self.source = source
        self.smc = smc
    }

    /// - Parameter sensorTemperature: battery temperature from the HID/SMC sensors, used
    ///   when the registry does not publish one.
    func sample(sensorTemperature: SensorValue<Double>) -> BatteryMetrics {
        guard let reading = source.read() else { return .notPresent }

        let temperature: SensorValue<Double>
        if let registry = reading.registryTemperatureCelsius {
            temperature = .available(registry, detail: "AppleSmartBattery")
        } else {
            temperature = sensorTemperature
        }

        let state: ChargingState
        if reading.isCharging { state = .charging }
        else if reading.isOnACPower { state = .pluggedIn }
        else { state = .discharging }

        // Adapter Specs
        let adapter: PowerAdapterSpecs
        let flow: PowerFlow

        if reading.isOnACPower {
            let measuredV = smc?.number("VD0R") ?? reading.adapterRatedVoltageVolts ?? reading.batteryVoltageVolts
            let measuredI = smc?.number("ID0R")
            let measuredW = smc?.number("PDTR") ?? (measuredV != nil && measuredI != nil ? measuredV! * measuredI! : reading.adapterRatedWatts)

            adapter = PowerAdapterSpecs(
                isConnected: true,
                name: reading.adapterDescription ?? "Power Adapter",
                currentAmps: measuredI != nil ? .available(measuredI!) : .unavailable("N/A"),
                maxCurrentAmps: reading.adapterRatedCurrentAmps,
                voltageVolts: measuredV != nil ? .available(measuredV!) : .unavailable("N/A"),
                maxVoltageVolts: reading.adapterRatedVoltageVolts,
                powerWatts: measuredW != nil ? .available(measuredW!) : .unavailable("N/A"),
                maxWatts: reading.adapterRatedWatts
            )

            let adapterWatts = measuredW ?? (reading.adapterRatedWatts ?? 0)
            let batAmps = reading.batteryAmperageAmps ?? 0
            let batVolts = reading.batteryVoltageVolts ?? 12.0
            let batChargingW: Double
            if reading.isCharging || batAmps > 0.05 {
                batChargingW = max(0, batAmps * batVolts)
            } else {
                batChargingW = 0.0
            }

            let systemWatts: Double
            if let pstr = smc?.number("PSTR"), pstr > 0.5 {
                systemWatts = pstr
            } else {
                systemWatts = max(0, adapterWatts - batChargingW)
            }

            flow = PowerFlow(
                isConnected: true,
                adapterWatts: adapterWatts,
                batteryWatts: batChargingW,
                systemWatts: systemWatts
            )
        } else {
            adapter = .disconnected
            let batAmps = reading.batteryAmperageAmps ?? 0
            let batVolts = reading.batteryVoltageVolts ?? 12.0
            let dischargeW = abs(batAmps) > 0.05 ? abs(batAmps * batVolts) : (smc?.number("PSTR") ?? 0)
            flow = PowerFlow(
                isConnected: false,
                adapterWatts: 0,
                batteryWatts: -dischargeW,
                systemWatts: dischargeW
            )
        }

        return BatteryMetrics(
            percent: .available(reading.percent),
            temperature: temperature,
            chargingState: state,
            adapter: adapter,
            flow: flow
        )
    }
}

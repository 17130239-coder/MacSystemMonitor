import Foundation
import IOKit

/// A temperature sensor as reported by a low-level interface, before classification.
struct RawSensor: Sendable, Equatable {
    var id: Int
    var name: String
}

/// A low-level temperature interface (IOHID event system, AppleSMC, …).
/// Abstracted so the discovery/aggregation logic can be tested with mock data.
protocol TemperatureProbe: AnyObject {
    var sourceName: String { get }
    func listSensors() -> [RawSensor]
    func readCelsius(_ sensor: RawSensor) -> Double?
}

// MARK: - IOHID (private-but-exported symbols)

// Apple Silicon exposes its thermal sensors through the IOHID *event system*
// (usage page 0xFF00, usage 5). The client API lives in IOKit but is not in the
// public headers, so we bind to the exported symbols directly. These calls need
// no entitlement and no root, but they do not work inside the App Sandbox.
@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: AnyObject, _ matching: CFDictionary) -> Int32
@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: AnyObject) -> Unmanaged<CFArray>?
@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: AnyObject, _ key: CFString) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: AnyObject, _ type: Int64, _ options: Int32, _ timestamp: Int64) -> Unmanaged<AnyObject>?
@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: AnyObject, _ field: Int32) -> Double

final class HIDTemperatureProbe: TemperatureProbe {
    let sourceName = "HID"

    private static let temperatureEventType: Int64 = 15            // kIOHIDEventTypeTemperature
    private static let temperatureField: Int32 = 15 << 16          // kIOHIDEventFieldTemperatureLevel

    private let client: AnyObject
    private let services: [AnyObject]

    init?() {
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault)?.takeRetainedValue() else { return nil }
        let matching: [String: Any] = ["PrimaryUsagePage": 0xFF00, "PrimaryUsage": 5]
        _ = IOHIDEventSystemClientSetMatching(client, matching as CFDictionary)
        guard let array = IOHIDEventSystemClientCopyServices(client)?.takeRetainedValue() as? [AnyObject],
              !array.isEmpty else { return nil }
        self.client = client
        self.services = array
    }

    func listSensors() -> [RawSensor] {
        services.enumerated().compactMap { index, service in
            guard let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString)?
                .takeRetainedValue() as? String else { return nil }
            return RawSensor(id: index, name: name)
        }
    }

    func readCelsius(_ sensor: RawSensor) -> Double? {
        guard services.indices.contains(sensor.id),
              let event = IOHIDServiceClientCopyEvent(services[sensor.id], Self.temperatureEventType, 0, 0)?
                .takeRetainedValue() else { return nil }
        let value = IOHIDEventGetFloatValue(event, Self.temperatureField)
        return value.isFinite ? value : nil
    }
}

// MARK: - SMC

final class SMCTemperatureProbe: TemperatureProbe {
    let sourceName = "SMC"
    private let smc: SMCReading

    init(smc: SMCReading) { self.smc = smc }

    func listSensors() -> [RawSensor] {
        guard let count = smc.keyCount() else { return [] }
        var result: [RawSensor] = []
        for index in 0 ..< count {
            // Only temperature keys ("T…") that hold floats are interesting.
            guard let key = smc.key(at: index), key.hasPrefix("T"),
                  smc.read(key)?.type == "flt " else { continue }
            result.append(RawSensor(id: index, name: key))
        }
        return result
    }

    func readCelsius(_ sensor: RawSensor) -> Double? {
        smc.read(sensor.name)?.number
    }
}

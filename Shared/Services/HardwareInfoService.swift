import Foundation

/// Detects the Mac model, chip, memory, battery and fan presence. Nothing is hard-coded
/// to a particular configuration; unknown models fall back to a generic name.
enum HardwareInfoService {
    static func detect(smc: SMCReading?,
                       batterySource: BatterySource = IOKitBatterySource(),
                       sensors: [DiscoveredSensor]) -> HardwareInfo {
        let identifier = sysctlString("hw.model") ?? "Unknown"
        let hasBattery = batterySource.read() != nil
        let name = modelName(identifier: identifier, hasBattery: hasBattery)
        let fans = FanService(smc: smc, modelIdentifier: identifier, modelName: name).detectFanCount()
        return HardwareInfo(
            modelIdentifier: identifier,
            modelName: name,
            chipName: chipName(),
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            hasBattery: hasBattery,
            hasFan: fans.map { $0 > 0 },
            fanCount: fans ?? 0,
            discoveredSensors: SensorDiscoveryService.summaries(of: sensors)
        )
    }

    /// "Apple M1 Pro" from `machdep.cpu.brand_string`.
    static func chipName() -> String {
        let brand = sysctlString("machdep.cpu.brand_string")?.trimmingCharacters(in: .whitespaces) ?? ""
        return brand.isEmpty ? "Apple Silicon" : brand
    }

    /// Marketing family name from the model identifier.
    /// Older-style identifiers carry the family ("MacBookPro18,1"); newer ones are
    /// generic ("Mac14,2") and are resolved through a table of known Apple Silicon IDs.
    static func modelName(identifier: String, hasBattery: Bool) -> String {
        let families: [(prefix: String, name: String)] = [
            ("MacBookPro", "MacBook Pro"), ("MacBookAir", "MacBook Air"), ("MacBook", "MacBook"),
            ("Macmini", "Mac mini"), ("MacPro", "Mac Pro"), ("MacStudio", "Mac Studio"), ("iMac", "iMac"),
        ]
        for family in families where identifier.hasPrefix(family.prefix) { return family.name }

        if let known = genericIdentifiers[identifier] { return known }
        if identifier.hasPrefix("Mac") { return hasBattery ? "MacBook" : "Mac" }
        return "Mac"
    }

    private static let genericIdentifiers: [String: String] = [
        // M2
        "Mac14,2": "MacBook Air", "Mac14,15": "MacBook Air",
        "Mac14,7": "MacBook Pro", "Mac14,5": "MacBook Pro", "Mac14,9": "MacBook Pro",
        "Mac14,6": "MacBook Pro", "Mac14,10": "MacBook Pro",
        "Mac14,3": "Mac mini", "Mac14,12": "Mac mini",
        "Mac14,13": "Mac Studio", "Mac14,14": "Mac Studio", "Mac14,8": "Mac Pro",
        // M1 Studio
        "Mac13,1": "Mac Studio", "Mac13,2": "Mac Studio",
        // M3
        "Mac15,12": "MacBook Air", "Mac15,13": "MacBook Air",
        "Mac15,3": "MacBook Pro", "Mac15,6": "MacBook Pro", "Mac15,7": "MacBook Pro",
        "Mac15,8": "MacBook Pro", "Mac15,9": "MacBook Pro", "Mac15,10": "MacBook Pro", "Mac15,11": "MacBook Pro",
        "Mac15,4": "iMac", "Mac15,5": "iMac",
        // M4
        "Mac16,1": "MacBook Pro", "Mac16,5": "MacBook Pro", "Mac16,6": "MacBook Pro",
        "Mac16,7": "MacBook Pro", "Mac16,8": "MacBook Pro",
        "Mac16,2": "iMac", "Mac16,3": "iMac",
        "Mac16,10": "Mac mini", "Mac16,11": "Mac mini",
        "Mac16,12": "MacBook Air", "Mac16,13": "MacBook Air",
    ]

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}

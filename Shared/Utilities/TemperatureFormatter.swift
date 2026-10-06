import Foundation

enum TemperatureFormatter {
    static let notAvailable = "N/A"

    /// 58.734 -> "59°C". Never shows decimals.
    static func string(celsius: Double?) -> String {
        guard let celsius, celsius.isFinite else { return notAvailable }
        return "\(Int(celsius.rounded()))°C"
    }

    static func string(_ sensor: SensorValue<Double>) -> String {
        sensor.isAvailable ? string(celsius: sensor.value) : notAvailable
    }

    // MARK: - Raw → °C conversions

    /// AppleSmartBattery's `Temperature` key is in hundredths of a degree Celsius
    /// (e.g. 3290 -> 32.9 °C).
    static func celsius(fromCentiDegrees raw: Int) -> Double { Double(raw) / 100.0 }

    /// SMC fixed-point `sp78`: signed 8.8 big-endian (e.g. 0x3A80 -> 58.5).
    static func celsius(fromSP78 high: UInt8, _ low: UInt8) -> Double {
        let raw = Int16(bitPattern: UInt16(high) << 8 | UInt16(low))
        return Double(raw) / 256.0
    }

    static func celsius(fromKelvin kelvin: Double) -> Double { kelvin - 273.15 }

    /// A plausible on-die/battery/NAND temperature. Rejects 0 °C (an unpopulated
    /// SMC key) and absurd values.
    static func isPlausible(_ celsius: Double) -> Bool {
        celsius.isFinite && celsius > 1 && celsius < 130
    }
}

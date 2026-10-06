import Foundation

enum ByteFormatter {
    static let gibibyte = Double(1 << 30)

    /// 8.4 / 16 GB  –  "GB" here means GiB (2^30), the same unit Activity Monitor uses.
    static func memoryString(used: UInt64, total: UInt64) -> String {
        "\(gigabytes(Double(used) / gibibyte)) / \(gigabytes(Double(total) / gibibyte)) GB"
    }

    /// One decimal, dropped when the value is (nearly) whole: 16 -> "16", 8.43 -> "8.4".
    static func gigabytes(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() { return String(Int(rounded)) }
        return String(format: "%.1f", rounded)
    }
}

enum PercentFormatter {
    /// The integer percentage shown to the user. Bars use this same integer so
    /// the bar always matches the text exactly.
    static func integer(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(min(100, max(0, value)).rounded())
    }

    static func string(_ value: Double) -> String { "\(integer(value))%" }

    /// 0...1 fraction corresponding exactly to the displayed integer.
    static func fraction(_ value: Double) -> Double { Double(integer(value)) / 100.0 }
}

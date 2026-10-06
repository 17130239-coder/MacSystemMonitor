import Foundation
import IOKit

/// One decoded SMC key.
struct SMCValue: Sendable, Equatable {
    var key: String
    /// Four-character SMC type code, e.g. "flt ", "ui8 ", "sp78".
    var type: String
    var bytes: [UInt8]

    /// Numeric interpretation for the types we care about; nil otherwise.
    var number: Double? {
        switch type {
        case "flt ":
            guard bytes.count >= 4 else { return nil }
            // On Apple Silicon the SMC returns native (little-endian) IEEE-754 floats.
            let bits = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
            let f = Float(bitPattern: bits)
            return f.isFinite ? Double(f) : nil
        case "ui8 ":
            return bytes.first.map(Double.init)
        case "ui16":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            guard bytes.count >= 4 else { return nil }
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        case "sp78":
            guard bytes.count >= 2 else { return nil }
            return TemperatureFormatter.celsius(fromSP78: bytes[0], bytes[1])
        case "fpe2":
            guard bytes.count >= 2 else { return nil }
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])) / 4.0
        default:
            return nil
        }
    }
}

/// Abstraction over AppleSMC so services can be unit-tested with a mock.
protocol SMCReading: AnyObject {
    func keyCount() -> Int?
    func key(at index: Int) -> String?
    func read(_ key: String) -> SMCValue?
}

extension SMCReading {
    func number(_ key: String) -> Double? { read(key)?.number }
}

/// Minimal user-space client for `AppleSMC`.
///
/// Works as a normal (non-root) user on Apple Silicon, but is blocked inside the
/// App Sandbox – which is why the main app is *not* sandboxed and the widget
/// extension (which must be) gets its data from a snapshot file instead.
///
/// The request/response struct (`SMCKeyData_t` in the kernel) is 80 bytes; we
/// build it as a raw byte buffer with explicit offsets to avoid any Swift struct
/// layout ambiguity:
///
///     0  UInt32 key          28 UInt32 keyInfo.dataSize   42 UInt8  command (data8)
///     4  SMCVersion (6 B)    32 UInt32 keyInfo.dataType   44 UInt32 index (data32)
///     12 SMCPLimitData(16 B) 36 UInt8  keyInfo.attributes 48 [32]   payload bytes
///                            40 UInt8  result
final class SMCConnection: SMCReading {
    private enum Offset {
        static let key = 0, dataSize = 28, dataType = 32, result = 40, command = 42, index = 44, payload = 48
    }
    private enum Command: UInt8 {
        case readBytes = 5, readIndex = 8, readKeyInfo = 9
    }
    private static let structSize = 80
    private static let handleYPCEvent: UInt32 = 2

    private var connection: io_connect_t = 0
    private var infoCache: [UInt32: (size: UInt32, type: UInt32)] = [:]

    /// Fails (nil) when AppleSMC is not present or macOS denies access.
    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS, connection != 0 else {
            return nil
        }
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    // MARK: SMCReading

    func keyCount() -> Int? {
        guard let value = read("#KEY"), let n = value.number else { return nil }
        return Int(n)
    }

    func key(at index: Int) -> String? {
        var input = [UInt8](repeating: 0, count: Self.structSize)
        input[Offset.command] = Command.readIndex.rawValue
        Self.store(UInt32(index), in: &input, at: Offset.index)
        guard let output = call(input) else { return nil }
        let code = Self.load(from: output, at: Offset.key)
        return code == 0 ? nil : Self.string(fromFourCC: code)
    }

    func read(_ key: String) -> SMCValue? {
        guard key.utf8.count == 4 else { return nil }
        let code = Self.fourCC(key)

        let info: (size: UInt32, type: UInt32)
        if let cached = infoCache[code] {
            info = cached
        } else {
            var input = [UInt8](repeating: 0, count: Self.structSize)
            Self.store(code, in: &input, at: Offset.key)
            input[Offset.command] = Command.readKeyInfo.rawValue
            guard let output = call(input) else { return nil }
            let size = Self.load(from: output, at: Offset.dataSize)
            let type = Self.load(from: output, at: Offset.dataType)
            guard size > 0, size <= 32 else { return nil }
            info = (size, type)
            infoCache[code] = info
        }

        var input = [UInt8](repeating: 0, count: Self.structSize)
        Self.store(code, in: &input, at: Offset.key)
        Self.store(info.size, in: &input, at: Offset.dataSize)
        input[Offset.command] = Command.readBytes.rawValue
        guard let output = call(input) else { return nil }
        let bytes = Array(output[Offset.payload ..< Offset.payload + Int(info.size)])
        return SMCValue(key: key, type: Self.string(fromFourCC: info.type), bytes: bytes)
    }

    // MARK: Plumbing

    private func call(_ input: [UInt8]) -> [UInt8]? {
        var output = [UInt8](repeating: 0, count: Self.structSize)
        var outputSize = Self.structSize
        let status = input.withUnsafeBytes { inBuf in
            output.withUnsafeMutableBytes { outBuf in
                IOConnectCallStructMethod(connection, Self.handleYPCEvent,
                                          inBuf.baseAddress, Self.structSize,
                                          outBuf.baseAddress, &outputSize)
            }
        }
        guard status == KERN_SUCCESS, output[Offset.result] == 0 else { return nil }
        return output
    }

    private static func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    private static func string(fromFourCC code: UInt32) -> String {
        let bytes = [UInt8(code >> 24 & 0xFF), UInt8(code >> 16 & 0xFF), UInt8(code >> 8 & 0xFF), UInt8(code & 0xFF)]
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func store(_ value: UInt32, in buffer: inout [UInt8], at offset: Int) {
        buffer.withUnsafeMutableBytes { $0.storeBytes(of: value, toByteOffset: offset, as: UInt32.self) }
    }

    private static func load(from buffer: [UInt8], at offset: Int) -> UInt32 {
        buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    }
}

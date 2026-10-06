import Foundation

/// Fan detection and RPM via AppleSMC (`FNum`, `F<n>Ac`).
///
/// Decision table:
/// | SMC reachable | `FNum` | Result                                   |
/// |---------------|--------|------------------------------------------|
/// | yes           | 0      | `.fanless` → UI shows "Fanless"          |
/// | yes           | n > 0  | RPM = mean of `F0Ac…F<n-1>Ac`            |
/// | yes           | absent | fanless if the model is a known fanless family, else unknown |
/// | no            | –      | fanless if the model is a known fanless family, else unknown → "N/A" |
///
/// A *stopped* fan on a Mac that has one is reported as `0` RPM (a real reading);
/// only a Mac without a fan is reported as "Fanless".
final class FanService {
    private let smc: SMCReading?
    private let modelIdentifier: String
    private let modelName: String

    init(smc: SMCReading?, modelIdentifier: String, modelName: String) {
        self.smc = smc
        self.modelIdentifier = modelIdentifier
        self.modelName = modelName
    }

    /// Families that have never shipped with a fan. (Apple Silicon MacBook Air.)
    static func isKnownFanless(modelName: String, modelIdentifier: String) -> Bool {
        modelName == "MacBook Air" || modelIdentifier.hasPrefix("MacBookAir")
    }

    /// Number of fans, or nil when it cannot be determined.
    func detectFanCount() -> Int? {
        if let smc, let n = smc.number("FNum") { return max(0, Int(n)) }
        return Self.isKnownFanless(modelName: modelName, modelIdentifier: modelIdentifier) ? 0 : nil
    }

    func sample() -> FanMetrics {
        let count = detectFanCount()
        switch count {
        case .some(0):
            return .fanless
        case .none:
            let reason = smc == nil ? "AppleSMC could not be opened, so the fan cannot be queried."
                                    : "AppleSMC does not report a fan count (FNum)."
            return FanMetrics(presence: .unknown, fanCount: 0, rpm: .unavailable(reason))
        case .some(let n):
            guard let smc else {
                return FanMetrics(presence: .present, fanCount: n, rpm: .unavailable("AppleSMC could not be opened."))
            }
            var fanDetails: [FanDetail] = []
            for i in 0 ..< n {
                if let speed = smc.number("F\(i)Ac"), speed.isFinite, speed >= 0 {
                    let minRPM = smc.number("F\(i)Mn")
                    let maxRPM = smc.number("F\(i)Mx")
                    let label: String = {
                        if n == 2 {
                            return i == 0 ? "Left" : "Right"
                        } else {
                            return "Fan \(i + 1)"
                        }
                    }()
                    fanDetails.append(FanDetail(id: i, label: label, rpm: speed, minRPM: minRPM, maxRPM: maxRPM))
                }
            }
            guard !fanDetails.isEmpty else {
                return FanMetrics(presence: .present, fanCount: n, rpm: .unavailable("Fan speed key F0Ac is not readable."))
            }
            let mean = fanDetails.map(\.rpm).reduce(0, +) / Double(fanDetails.count)
            return FanMetrics(presence: .present, fanCount: n, rpm: .available(mean), fans: fanDetails)
        }
    }
}

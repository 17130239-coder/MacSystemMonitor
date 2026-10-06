import Foundation

enum SystemStatus: String, Codable, Sendable, Equatable, Comparable {
    case unknown, normal, warm, hot

    var label: String {
        switch self {
        case .unknown: return "N/A"
        case .normal: return "Normal"
        case .warm: return "Warm"
        case .hot: return "Hot"
        }
    }

    private var rank: Int {
        switch self {
        case .unknown: return -1
        case .normal: return 0
        case .warm: return 1
        case .hot: return 2
        }
    }
    static func < (l: Self, r: Self) -> Bool { l.rank < r.rank }
}

/// Derives `Normal / Warm / Hot` from the temperature sensors that are available.
///
/// IMPORTANT: these thresholds are this app's own heuristics. They are **not**
/// official Apple thermal limits.
///
/// | Sensor  | Warm at | Hot at |
/// |---------|---------|--------|
/// | CPU     | 75 °C   | 90 °C  |
/// | GPU     | 75 °C   | 90 °C  |
/// | Battery | 38 °C   | 45 °C  |
/// | SSD     | 70 °C   | 80 °C  |
///
/// Anti-flicker mechanics:
/// * Each sensor is smoothed with an exponential moving average (`smoothing`),
///   so a one-sample spike barely moves the value.
/// * Hysteresis: once a sensor has escalated, it must fall `hysteresis` °C
///   below the threshold before the state de-escalates.
/// * The overall status is the worst per-sensor state.
struct StatusEvaluator: Sendable {
    struct Thresholds: Sendable, Equatable {
        var warm: Double
        var hot: Double
    }

    static let defaultThresholds: [TemperatureCategory: Thresholds] = [
        .cpu: Thresholds(warm: 75, hot: 90),
        .gpu: Thresholds(warm: 75, hot: 90),
        .battery: Thresholds(warm: 38, hot: 45),
        .ssd: Thresholds(warm: 70, hot: 80),
    ]

    var thresholds = StatusEvaluator.defaultThresholds
    /// Weight of the newest sample in the EMA (0...1).
    var smoothing = 0.25
    var hysteresis = 3.0

    private var smoothed: [TemperatureCategory: Double] = [:]
    private var states: [TemperatureCategory: SystemStatus] = [:]

    init(thresholds: [TemperatureCategory: Thresholds] = StatusEvaluator.defaultThresholds,
         smoothing: Double = 0.25, hysteresis: Double = 3.0) {
        self.thresholds = thresholds
        self.smoothing = smoothing
        self.hysteresis = hysteresis
    }

    /// Feed the latest readings (nil = sensor unavailable) and get the overall status.
    mutating func update(_ readings: [TemperatureCategory: Double?]) -> SystemStatus {
        var worst = SystemStatus.unknown
        for category in TemperatureCategory.allCases {
            guard let limit = thresholds[category], let maybe = readings[category], let sample = maybe else {
                smoothed[category] = nil
                states[category] = nil
                continue
            }
            let value: Double
            if let previous = smoothed[category] {
                value = previous + smoothing * (sample - previous)
            } else {
                value = sample
            }
            smoothed[category] = value

            let current = states[category] ?? .normal
            let next = Self.nextState(from: current, value: value, limit: limit, hysteresis: hysteresis)
            states[category] = next
            worst = max(worst, next)
        }
        return worst
    }

    static func nextState(from current: SystemStatus, value: Double, limit: Thresholds, hysteresis: Double) -> SystemStatus {
        // Escalation is immediate once the smoothed value crosses the threshold.
        var state = current
        if value >= limit.hot { state = .hot }
        else if value >= limit.warm, state < .warm { state = .warm }

        // De-escalation requires dropping `hysteresis` below the threshold.
        if state == .hot, value < limit.hot - hysteresis { state = .warm }
        if state == .warm, value < limit.warm - hysteresis { state = .normal }
        return state
    }
}

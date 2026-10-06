import Foundation

/// The 5 sequential steps of a complete battery recalibration cycle.
enum CalibrationStep: Int, CaseIterable, Identifiable, Codable {
    case chargeTo100 = 1
    case dischargeTo10 = 2
    case chargeTo100Final = 3
    case holdFor = 4
    case dischargeTo80 = 5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .chargeTo100: return "Charge to 100%"
        case .dischargeTo10: return "Discharge to 10%"
        case .chargeTo100Final: return "Charge to 100%"
        case .holdFor: return "Hold for"
        case .dischargeTo80: return "Discharge to 80%"
        }
    }

    var targetPercent: Double {
        switch self {
        case .chargeTo100, .chargeTo100Final, .holdFor: return 100.0
        case .dischargeTo10: return 10.0
        case .dischargeTo80: return 80.0
        }
    }

    var instruction: String {
        switch self {
        case .chargeTo100: return "Connect charger to reach 100%"
        case .dischargeTo10: return "Disconnect charger to discharge to 10%"
        case .chargeTo100Final: return "Connect charger to recharge to 100%"
        case .holdFor: return "Keep plugged in to balance battery cells"
        case .dischargeTo80: return "Disconnect charger to discharge to 80%"
        }
    }
}

/// The runtime state of the calibration process.
enum CalibrationState: Codable, Equatable {
    case idle
    case active(step: CalibrationStep, holdSecondsRemaining: TimeInterval?)
    case completed(date: Date)

    var isActive: Bool {
        if case .active = self { return true }
        return false
    }

    var currentStep: CalibrationStep? {
        if case .active(let step, _) = self { return step }
        return nil
    }
}

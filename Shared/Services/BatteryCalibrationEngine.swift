import Foundation
import Observation
import UserNotifications

/// Coordinates the 5-step battery recalibration pipeline and alerts the user
/// during state transitions.
@MainActor
@Observable
final class BatteryCalibrationEngine {
    static let shared = BatteryCalibrationEngine()

    private(set) var state: CalibrationState = .idle
    private(set) var lastCalibrationDate: Date?

    var holdDuration: TimeInterval = 3600 // 1 hour default
    @ObservationIgnored private var holdTask: Task<Void, Never>?

    private static let lastCalibrationKey = "batteryLastCalibrationTimestamp"

    init() {
        if let stored = UserDefaults.standard.object(forKey: Self.lastCalibrationKey) as? Date {
            self.lastCalibrationDate = stored
        }
        requestNotificationPermission()
    }

    func start() {
        state = .active(step: .chargeTo100, holdSecondsRemaining: nil)
        sendNotification(
            title: "Calibration Started",
            body: "Step 1: Charge to 100%. Please keep your Mac plugged in."
        )
    }

    func cancel() {
        holdTask?.cancel()
        holdTask = nil
        state = .idle
    }

    func update(currentPercent: Double, isConnected: Bool) {
        guard case .active(let step, _) = state else { return }

        switch step {
        case .chargeTo100:
            if currentPercent >= 99.5 {
                advance(to: .dischargeTo10)
                sendNotification(
                    title: "Calibration: Step 1 Complete",
                    body: "Battery reached 100%! Please unplug charger to discharge to 10%."
                )
            }

        case .dischargeTo10:
            if currentPercent <= 10.5 {
                advance(to: .chargeTo100Final)
                sendNotification(
                    title: "Calibration: Step 2 Complete",
                    body: "Battery reached 10%! Please connect charger to recharge to 100%."
                )
            }

        case .chargeTo100Final:
            if currentPercent >= 99.5 {
                advance(to: .holdFor)
                startHoldCountdown()
                sendNotification(
                    title: "Calibration: Step 3 Complete",
                    body: "Battery reached 100%! Holding for 1 hour to balance battery cells."
                )
            }

        case .holdFor:
            // Managed by holdTask
            break

        case .dischargeTo80:
            if currentPercent <= 80.5 {
                completeCalibration()
            }
        }
    }

    private func advance(to nextStep: CalibrationStep) {
        holdTask?.cancel()
        holdTask = nil
        state = .active(step: nextStep, holdSecondsRemaining: nextStep == .holdFor ? holdDuration : nil)
    }

    private func startHoldCountdown() {
        holdTask?.cancel()
        state = .active(step: .holdFor, holdSecondsRemaining: holdDuration)
        holdTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var remaining = self.holdDuration
            while remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                remaining -= 1.0
                self.state = .active(step: .holdFor, holdSecondsRemaining: remaining)
            }
            if !Task.isCancelled {
                self.advance(to: .dischargeTo80)
                self.sendNotification(
                    title: "Calibration: Cell Balancing Complete",
                    body: "Hold period finished! Please unplug charger to discharge to 80%."
                )
            }
        }
    }

    private func completeCalibration() {
        let now = Date()
        lastCalibrationDate = now
        UserDefaults.standard.set(now, forKey: Self.lastCalibrationKey)
        state = .completed(date: now)
        sendNotification(
            title: "Calibration Completed!",
            body: "Your MacBook battery management system has been successfully calibrated."
        )
    }

    private func requestNotificationPermission() {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.contains("xctest") else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        guard let bundleId = Bundle.main.bundleIdentifier, !bundleId.contains("xctest") else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

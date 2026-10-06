import SwiftUI

/// Renders the complete Battery Calibration Mode interface matching the design mockup.
struct BatteryCalibrationCardView: View {
    @Bindable var engine: BatteryCalibrationEngine = BatteryCalibrationEngine.shared
    var currentBatteryPercent: Double = 100.0

    @State private var showingHelpPopover: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar
            headerBar

            // 5-Step Pipeline Card
            pipelineCard

            // Footer Bar: Last Calibration
            footerBar
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
                )
        )
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MonitorTheme.primaryText)

            Text("Calibration Mode")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MonitorTheme.primaryText)

            Button {
                showingHelpPopover.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MonitorTheme.secondaryText)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingHelpPopover) {
                helpPopoverContent
            }
            .help("Learn about battery recalibration")

            Spacer()

            // Start / Stop Calibration Button
            actionButton
        }
    }

    private var actionButton: some View {
        Button {
            if engine.state.isActive {
                engine.cancel()
            } else {
                engine.start()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: engine.state.isActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 9, weight: .bold))

                Text(engine.state.isActive ? "Stop Calibration" : "Start Calibration")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(engine.state.isActive ? Color.white : MonitorTheme.secondaryText)
            .background(
                Capsule()
                    .fill(engine.state.isActive ? Color.red.opacity(0.3) : Color(white: 0.14))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                engine.state.isActive ? Color.red.opacity(0.5) : Color.white.opacity(0.12),
                                lineWidth: 0.75
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5-Step Pipeline Card

    private var pipelineCard: some View {
        HStack(spacing: 0) {
            ForEach(Array(CalibrationStep.allCases.enumerated()), id: \.element.id) { index, step in
                stepItem(step)
                    .frame(maxWidth: .infinity)

                if index < CalibrationStep.allCases.count - 1 {
                    arrowSeparator
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                )
        )
    }

    private func stepItem(_ step: CalibrationStep) -> some View {
        let isCurrent = engine.state.currentStep == step

        return VStack(spacing: 8) {
            CalibrationBatteryIconView(step: step, isActive: isCurrent)

            VStack(spacing: 2) {
                Text(stepTitle(step))
                    .font(.system(size: 10, weight: isCurrent ? .bold : .medium))
                    .foregroundStyle(isCurrent ? MonitorTheme.primaryText : MonitorTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if isCurrent {
                    Text(stepSubtitle(step))
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MonitorTheme.accentGreen)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(MonitorTheme.accentGreen.opacity(0.15))
                        )
                }
            }
        }
    }

    private func stepTitle(_ step: CalibrationStep) -> String {
        switch step {
        case .chargeTo100: return "Charge to\n100%"
        case .dischargeTo10: return "Discharge\nto 10%"
        case .chargeTo100Final: return "Charge to\n100%"
        case .holdFor: return "Hold for"
        case .dischargeTo80: return "Discharge\nto 80%"
        }
    }

    private func stepSubtitle(_ step: CalibrationStep) -> String {
        switch step {
        case .chargeTo100, .chargeTo100Final:
            return "\(Int(currentBatteryPercent))% · In Progress"
        case .dischargeTo10, .dischargeTo80:
            return "\(Int(currentBatteryPercent))% · In Progress"
        case .holdFor:
            if case .active(_, let remaining) = engine.state, let rem = remaining {
                let mins = max(1, Int(rem / 60))
                return "\(mins)m left"
            }
            return "Active"
        }
    }

    private var arrowSeparator: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(MonitorTheme.tertiaryText)
            .padding(.horizontal, 2)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            if engine.state.isActive, let current = engine.state.currentStep {
                HStack(spacing: 4) {
                    Circle()
                        .fill(MonitorTheme.accentGreen)
                        .frame(width: 5, height: 5)
                    Text(current.instruction)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(MonitorTheme.secondaryText)
                }
            }

            Spacer()

            Text("Last Calibration: \(formattedLastDate)")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(MonitorTheme.secondaryText)
        }
        .padding(.horizontal, 2)
    }

    private var formattedLastDate: String {
        guard let date = engine.lastCalibrationDate else { return "-" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Help Popover

    private var helpPopoverContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why Calibrate the Battery?")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MonitorTheme.primaryText)

            Text("Operating your Mac on charge limiters (e.g. 80%) can cause the Battery Management System (BMS) fuel gauge to drift over time.")
                .font(.system(size: 10.5))
                .foregroundStyle(MonitorTheme.secondaryText)

            Text("A full cycle (100% ➔ 10% ➔ 100% ➔ Hold ➔ 80%) recalibrates the battery's maximum capacity reading, restores accurate percentages, and prevents unexpected shutdowns.")
                .font(.system(size: 10.5))
                .foregroundStyle(MonitorTheme.secondaryText)
        }
        .padding(12)
        .frame(width: 260)
    }
}

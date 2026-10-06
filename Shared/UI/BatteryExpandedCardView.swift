import SwiftUI

/// Enlarged Battery & Power card containing battery health, charge state,
/// interactive Power Flow Sankey diagram, Power Adapter specs, and Calibration Mode.
struct BatteryExpandedCardView: View {
    var metrics: SystemMetrics
    var density: MonitorDensity = .large

    @State private var selectedSection: BatterySection = .powerFlow

    enum BatterySection: String, CaseIterable {
        case powerFlow = "Power Flow"
        case calibration = "Calibration"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Title, Status Pill, Section Switcher on left; Big % and Temp on right
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("BATTERY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MonitorTheme.secondaryText)
                        .tracking(0.5)

                    statusBadge

                    sectionSwitcher
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(metrics.batteryPercentText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(MonitorTheme.primaryText)

                    Text(metrics.batteryTemperatureText)
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(MonitorTheme.secondaryText)
                }
            }

            // Battery Level Bar
            if let pct = metrics.battery.percent.value {
                UsageBar(fraction: pct / 100.0, height: 4)
            }

            // Sub-sections: Power Flow & Adapter Specs OR Calibration Mode
            Group {
                if selectedSection == .powerFlow {
                    HStack(alignment: .top, spacing: 14) {
                        PowerFlowView(flow: metrics.battery.flow)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 0.5)
                            .frame(maxHeight: .infinity)
                            .padding(.vertical, 4)

                        PowerAdapterSpecsView(specs: metrics.battery.adapter)
                            .frame(width: 175)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                    .padding(.top, 2)
                } else {
                    BatteryCalibrationCardView(
                        engine: BatteryCalibrationEngine.shared,
                        currentBatteryPercent: metrics.battery.percent.value ?? 100.0
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
                )
        )
    }

    private var sectionSwitcher: some View {
        HStack(spacing: 2) {
            sectionButton(title: "Flow", icon: "bolt.fill", section: .powerFlow)
            sectionButton(title: "Calibration", icon: "slider.horizontal.3", section: .calibration)
        }
        .padding(2)
        .background(
            Capsule()
                .fill(Color(white: 0.12))
        )
    }

    private func sectionButton(title: String, icon: String, section: BatterySection) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                Text(title)
                    .font(.system(size: 9.5, weight: selectedSection == section ? .bold : .medium))

                if section == .calibration && BatteryCalibrationEngine.shared.state.isActive {
                    Circle()
                        .fill(MonitorTheme.accentGreen)
                        .frame(width: 4.5, height: 4.5)
                        .shadow(color: MonitorTheme.accentGreen, radius: 2)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .foregroundStyle(selectedSection == section ? Color.white : MonitorTheme.secondaryText)
            .background(
                selectedSection == section ?
                    Capsule().fill(Color.white.opacity(0.14)) : nil
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusBadge: some View {
        let isCharging = metrics.battery.chargingState == .charging
        let isPluggedIn = metrics.battery.chargingState == .pluggedIn

        let label: String = {
            if isCharging { return "Charging" }
            if isPluggedIn {
                return (metrics.battery.percent.value ?? 0) >= 80 ? "Plugged In · 80% Limit" : "Plugged In"
            }
            return "On Battery"
        }()

        HStack(spacing: 4) {
            Circle()
                .fill(isCharging ? MonitorTheme.accentGreen : (isPluggedIn ? Color.blue : Color.orange))
                .frame(width: 5, height: 5)
                .shadow(color: isCharging ? MonitorTheme.accentGreen.opacity(0.8) : Color.clear, radius: 2)

            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(isCharging ? MonitorTheme.accentGreen : MonitorTheme.secondaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(isCharging ? MonitorTheme.accentGreen.opacity(0.12) : Color.white.opacity(0.06))
        )
    }
}

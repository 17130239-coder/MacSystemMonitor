import SwiftUI

/// Enlarged Battery & Power card containing battery health, charge state,
/// interactive Power Flow Sankey diagram, and Power Adapter specs.
struct BatteryExpandedCardView: View {
    var metrics: SystemMetrics
    var density: MonitorDensity = .large

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Title, Status Pill on left; Big % and Temp on right
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("BATTERY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MonitorTheme.secondaryText)
                        .tracking(0.5)

                    statusBadge
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

            // Two clean sub-panels
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

import SwiftUI

/// Detailed electrical specifications of the connected power adapter.
/// Displays measured vs rated Power, Voltage, and Current with utilization bar.
struct PowerAdapterSpecsView: View {
    var specs: PowerAdapterSpecs

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Adapter Specs")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(MonitorTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.5)

            if specs.isConnected {
                VStack(spacing: 9) {
                    // Power Row with Mini Usage Bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Power")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(MonitorTheme.secondaryText)
                            Spacer()
                            HStack(spacing: 3) {
                                Text(specs.powerWatts.value.map { String(format: "%.1f W", $0) } ?? "—")
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(MonitorTheme.primaryText)
                                if let max = specs.maxWatts {
                                    Text("/ " + String(format: "%.0f W", max))
                                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                                        .foregroundStyle(MonitorTheme.secondaryText)
                                }
                            }
                        }

                        // Utilization Bar
                        if let curr = specs.powerWatts.value, let max = specs.maxWatts, max > 0 {
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 3)
                                    Capsule()
                                        .fill(MonitorTheme.accentGreen.opacity(0.85))
                                        .frame(width: max > 0 ? min(g.size.width, g.size.width * CGFloat(curr / max)) : 0, height: 3)
                                }
                            }
                            .frame(height: 3)
                        }
                    }

                    // Voltage Row
                    HStack {
                        Text("Voltage")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(MonitorTheme.secondaryText)
                        Spacer()
                        HStack(spacing: 3) {
                            Text(specs.voltageVolts.value.map { String(format: "%.1f V", $0) } ?? "—")
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MonitorTheme.primaryText)
                            if let max = specs.maxVoltageVolts {
                                Text("/ " + String(format: "%.0f V", max))
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundStyle(MonitorTheme.secondaryText)
                            }
                        }
                    }

                    // Current Row
                    HStack {
                        Text("Current")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(MonitorTheme.secondaryText)
                        Spacer()
                        HStack(spacing: 3) {
                            Text(specs.currentAmps.value.map { String(format: "%.1f A", $0) } ?? "—")
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MonitorTheme.primaryText)
                            if let max = specs.maxCurrentAmps {
                                Text("/ " + String(format: "%.1f A", max))
                                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                                    .foregroundStyle(MonitorTheme.secondaryText)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "battery.100")
                        .font(.system(size: 20))
                        .foregroundStyle(MonitorTheme.secondaryText)
                    Text("Running on Battery")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MonitorTheme.secondaryText)
                    Text("No adapter connected")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(MonitorTheme.tertiaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

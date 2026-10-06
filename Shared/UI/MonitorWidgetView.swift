import SwiftUI

/// The single monitoring card. Used by both the main app window and the WidgetKit
/// widget, so the two always look identical. Pure rendering – no sensor logic.
struct MonitorWidgetView: View {
    var metrics: SystemMetrics
    /// Replaces the status label, e.g. when the widget has no fresh data.
    var statusOverride: String?
    /// Fixed density (WidgetKit family); `nil` = derive from the available size.
    var density: MonitorDensity?

    init(metrics: SystemMetrics, statusOverride: String? = nil, density: MonitorDensity? = nil) {
        self.metrics = metrics
        self.statusOverride = statusOverride
        self.density = density
    }

    var body: some View {
        GeometryReader { geo in
            let d = density ?? MonitorDensity.forSize(geo.size)
            VStack(alignment: .leading, spacing: d.headerSpacing) {
                header(d)
                if d == .small { smallGrid(d) } else { fullGrid(d) }
            }
            .padding(.horizontal, d.paddingHorizontal)
            .padding(.vertical, d.paddingVertical)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    // MARK: Header

    private func header(_ d: MonitorDensity) -> some View {
        let title = d == .small ? metrics.hardware.chipName : metrics.hardware.headerTitle
        let status = statusOverride ?? metrics.status.label
        let color = statusOverride == nil ? MonitorTheme.color(for: metrics.status) : MonitorTheme.secondaryText
        return HeaderView(title: title, statusText: status, statusColor: color, density: d)
    }

    // MARK: Cells

    private func cpu(_ d: MonitorDensity, withDetail: Bool) -> some View {
        MetricCard(title: "CPU", value: metrics.cpuDisplay.text, showsBar: true,
                   fraction: metrics.cpuDisplay.fraction,
                   detail: withDetail ? metrics.cpuTemperatureText : nil,
                   help: tooltip(metrics.cpuUsage, metrics.cpuTemperature), density: d)
    }

    private func gpu(_ d: MonitorDensity, withDetail: Bool) -> some View {
        MetricCard(title: "GPU", value: metrics.gpuDisplay.text, showsBar: true,
                   fraction: metrics.gpuDisplay.fraction,
                   detail: withDetail ? metrics.gpuTemperatureText : nil,
                   help: tooltip(metrics.gpuUsage, metrics.gpuTemperature), density: d)
    }

    private func ram(_ d: MonitorDensity, withDetail: Bool) -> some View {
        MetricCard(title: "RAM", value: metrics.memoryDisplay.text, showsBar: true,
                   fraction: metrics.memoryDisplay.fraction,
                   detail: withDetail ? (metrics.memoryDisplay.detail ?? "N/A") : nil,
                   help: metrics.memory.detail, density: d)
    }

    private func battery(_ d: MonitorDensity, withDetail: Bool) -> some View {
        var detail: String? = nil
        if withDetail {
            detail = metrics.batteryTemperatureText
            if d != .large, let state = metrics.batteryStateText { detail = "\(metrics.batteryTemperatureText) · \(state)" }
        }
        return MetricCard(title: "Battery", titleNote: d == .large ? metrics.batteryStateText : nil,
                          value: metrics.batteryPercentText, detail: detail,
                          help: tooltip(metrics.battery.percent, metrics.battery.temperature), density: d)
    }

    private func ssd(_ d: MonitorDensity) -> some View {
        MetricCard(title: "SSD", value: metrics.ssdTemperatureText,
                   detail: d == .large ? "Apple NAND" : nil,
                   help: metrics.ssdTemperature.detail, density: d)
    }

    @ViewBuilder
    private func fan(_ d: MonitorDensity) -> some View {
        let isFanless = metrics.fan.presence == .fanless
        if isFanless {
            MetricCard(title: "FAN", value: "Fanless", detail: "Passive Cooling",
                       help: metrics.fan.rpm.detail, density: d)
        } else if d == .large, let fans = metrics.fan.fans, fans.count >= 2 {
            dualFanTile(fans, density: d)
        } else {
            let val = metrics.fanValueText
            let det: String = {
                if let fans = metrics.fan.fans, fans.count >= 2 {
                    return "Dual · " + fans.map { "\(Int($0.rpm.rounded()))" }.joined(separator: "/")
                }
                return "RPM · Active"
            }()
            MetricCard(title: "FAN", value: val, detail: det,
                       help: fanHelpText, density: d)
        }
    }

    private func dualFanTile(_ fans: [FanDetail], density: MonitorDensity) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("FAN")
                    .font(.system(size: density.labelSize, weight: .semibold))
                    .foregroundStyle(MonitorTheme.secondaryText)
                Spacer()
                Text("\(fans.count) Fans")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MonitorTheme.accentGreen)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(
                        Capsule()
                            .fill(MonitorTheme.accentGreen.opacity(0.12))
                    )
            }

            VStack(spacing: 4) {
                ForEach(fans, id: \.id) { fan in
                    HStack {
                        Text(fan.label)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(MonitorTheme.secondaryText)
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(Int(fan.rpm.rounded()))")
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(MonitorTheme.primaryText)
                            Text("RPM")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(MonitorTheme.tertiaryText)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .help(fanHelpText)
    }

    private var fanHelpText: String {
        if let fans = metrics.fan.fans, !fans.isEmpty {
            return fans.map { fan in
                var text = "\(fan.label) Fan: \(Int(fan.rpm.rounded())) RPM"
                if let min = fan.minRPM, let max = fan.maxRPM {
                    text += " (Min: \(Int(min)), Max: \(Int(max)))"
                }
                return text
            }.joined(separator: "\n")
        }
        return metrics.fan.rpm.detail ?? ""
    }

    private func tooltip(_ a: SensorValue<Double>, _ b: SensorValue<Double>) -> String? {
        [a, b].compactMap { $0.isAvailable ? nil : $0.detail }.first
    }

    // MARK: Grids

    private func smallGrid(_ d: MonitorDensity) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell(cpu(d, withDetail: false), first: true)
                vDivider
                cell(gpu(d, withDetail: false), last: true)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
            hDivider
            HStack(spacing: 0) {
                cell(ram(d, withDetail: false), first: true)
                vDivider
                cell(battery(d, withDetail: false), last: true)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func fullGrid(_ d: MonitorDensity) -> some View {
        if d == .large {
            expandedBatteryGrid(d)
        } else {
            compactSixCellGrid(d)
        }
    }

    private func compactSixCellGrid(_ d: MonitorDensity) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                cell(cpu(d, withDetail: true), first: true)
                vDivider
                cell(gpu(d, withDetail: true))
                vDivider
                cell(ram(d, withDetail: true), last: true)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)

            hDivider

            HStack(spacing: 0) {
                cell(battery(d, withDetail: true), first: true)
                vDivider
                cell(ssd(d))
                vDivider
                cell(fan(d), last: true)
            }
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxHeight: .infinity)
    }

    private func expandedBatteryGrid(_ d: MonitorDensity) -> some View {
        VStack(spacing: 8) {
            // Row 1: 3 rounded tiles: CPU | GPU | RAM
            HStack(spacing: 8) {
                tile(cpu(d, withDetail: true))
                tile(gpu(d, withDetail: true))
                tile(ram(d, withDetail: true))
            }
            .frame(height: 104)

            // Row 2: Enlarged Battery (left ~70%) | Stacked SSD & Fan (right ~30%)
            HStack(spacing: 8) {
                BatteryExpandedCardView(metrics: metrics, density: d)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 8) {
                    tile(ssd(d))
                        .frame(maxHeight: .infinity)
                    tile(fan(d))
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 155)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private func tile<V: View>(_ view: V) -> some View {
        view
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
                    )
            )
    }

    private func cell<V: View>(_ view: V, first: Bool = false, last: Bool = false) -> some View {
        view
            .padding(.leading, first ? 0 : 8)
            .padding(.trailing, last ? 0 : 8)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var vDivider: some View {
        Rectangle().fill(MonitorTheme.separator).frame(width: 1).padding(.vertical, 2)
    }

    private var hDivider: some View {
        Rectangle().fill(MonitorTheme.separator).frame(height: 1)
    }
}

/// Rounded dark card chrome with a subtle border, used by the app window.
struct MonitorCardBackground: View {
    var cornerRadius: CGFloat = 20
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(MonitorTheme.background)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(MonitorTheme.border, lineWidth: 1)
            )
    }
}

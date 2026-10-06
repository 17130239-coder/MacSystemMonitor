import SwiftUI

/// One cell of the grid: label, primary value, optional usage bar, optional detail line.
/// Renders state only.
struct MetricCard: View {
    var title: String
    /// Subtle note next to the title (e.g. "Charging").
    var titleNote: String?
    var value: String
    var showsBar: Bool = false
    var fraction: Double?
    var detail: String?
    var help: String?
    var density: MonitorDensity

    private var isUnavailable: Bool { value == "N/A" }

    var body: some View {
        VStack(alignment: .leading, spacing: density.cellSpacing) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: density.labelSize, weight: .semibold))
                    .foregroundStyle(MonitorTheme.secondaryText)
                if let titleNote {
                    Text(titleNote)
                        .font(.system(size: density.labelSize, weight: .medium))
                        .foregroundStyle(MonitorTheme.accent)
                }
            }
            .lineLimit(1)

            Text(value)
                .font(.system(size: density.valueSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isUnavailable ? MonitorTheme.tertiaryText : MonitorTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())

            if showsBar {
                UsageBar(fraction: fraction, height: density.barHeight)
            }

            if let detail {
                Text(detail)
                    .font(.system(size: density.detailSize, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(detail == "N/A" ? MonitorTheme.tertiaryText : MonitorTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .help(help ?? "")
        .accessibilityElement(children: .combine)
    }
}

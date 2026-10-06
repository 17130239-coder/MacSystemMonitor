import SwiftUI

struct HeaderView: View {
    var title: String
    var statusText: String
    var statusColor: Color
    var density: MonitorDensity

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: density.headerSize, weight: .bold))
                .foregroundStyle(MonitorTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: statusColor.opacity(0.8), radius: 3)

                Text(statusText)
                    .font(.system(size: density.headerSize - 1, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.14))
            )
            .lineLimit(1)
        }
    }
}

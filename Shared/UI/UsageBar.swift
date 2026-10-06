import SwiftUI

/// Horizontal usage bar. `fraction` is exactly the displayed integer percentage / 100.
struct UsageBar: View {
    var fraction: Double?
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(MonitorTheme.track)
                if let fraction, fraction > 0 {
                    Capsule()
                        .fill(MonitorTheme.accent)
                        .frame(width: max(height, geo.size.width * fraction.clamped(to: 0 ... 1)))
                }
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.35), value: fraction)
        .accessibilityHidden(true)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double { min(max(self, range.lowerBound), range.upperBound) }
}

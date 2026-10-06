import SwiftUI

/// White-on-dark with a single green accent (matches the Apple battery widget look).
enum MonitorTheme {
    /// System-green (#30D158), the one accent colour.
    static let accent = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let accentGreen = accent
    static let warm = Color(red: 1.0, green: 0.80, blue: 0.0)
    static let hot = Color(red: 1.0, green: 0.27, blue: 0.23)

    static let background = Color(white: 0.085)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.60)
    static let tertiaryText = Color.white.opacity(0.38)
    static let track = Color.white.opacity(0.14)
    static let separator = Color.white.opacity(0.10)
    static let border = Color.white.opacity(0.12)

    static func color(for status: SystemStatus) -> Color {
        switch status {
        case .normal: return accent
        case .warm: return warm
        case .hot: return hot
        case .unknown: return secondaryText
        }
    }
}

/// Size-dependent metrics so one view adapts from a small widget to a large window.
enum MonitorDensity {
    /// Systemsmall-like: 2×2 grid with CPU, GPU, RAM, Battery.
    case small
    /// Systemmedium-like: full 3×2 grid.
    case regular
    /// Systemlarge / big window: full grid with roomier type.
    case large

    static func forSize(_ size: CGSize) -> MonitorDensity {
        if size.width < 230 { return .small }
        if size.height >= 250 && size.width >= 300 { return .large }
        return .regular
    }

    var padding: CGFloat { paddingHorizontal }
    var paddingHorizontal: CGFloat { self == .large ? 18 : 14 }
    var paddingVertical: CGFloat { self == .large ? 16 : 10 }
    var valueSize: CGFloat { self == .large ? 26 : (self == .small ? 18 : 18) }
    var labelSize: CGFloat { self == .large ? 11.5 : (self == .small ? 9.5 : 10) }
    var detailSize: CGFloat { self == .large ? 12 : (self == .small ? 9.5 : 10) }
    var barHeight: CGFloat { self == .large ? 5 : 3.5 }
    var cellSpacing: CGFloat { self == .large ? 4 : 2 }
    var headerSize: CGFloat { self == .large ? 13 : 11 }
    var headerSpacing: CGFloat { self == .large ? 10 : 6 }
}

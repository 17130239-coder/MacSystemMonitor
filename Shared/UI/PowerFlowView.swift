import SwiftUI

/// Sankey-style power distribution flow diagram.
/// Visualizes: Adapter Input ➔ Battery Charging + Mac System Load.
struct PowerFlowView: View {
    var flow: PowerFlow
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Power Flow")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(MonitorTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.5)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                let sourceW: CGFloat = 62
                let targetW: CGFloat = 44

                let leftX = sourceW / 2
                let leftY = h / 2

                let rightX = w - targetW / 2
                let rightTopY = h * 0.27
                let rightBottomY = h * 0.73

                let startX = sourceW
                let endX = w - targetW

                ZStack {
                    // 1. Ribbons Layer: Animated Energy Wave Shimmer
                    // Isolated inside TimelineView at a capped 60 FPS so static nodes/pills are never redrawn
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: scenePhase == .background)) { timeline in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        let cycleDuration: Double = 4.2
                        let progress = CGFloat((now / cycleDuration).truncatingRemainder(dividingBy: 1.0))

                        ZStack {
                            if flow.isConnected {
                                // Top Ribbon: Adapter -> Battery
                                if flow.batteryWatts > 0.1 {
                                    AnimatedRibbon(
                                        startX: startX,
                                        startYTop: leftY - 18,
                                        startYBottom: leftY - 1,
                                        endX: endX,
                                        endYTop: rightTopY - 13,
                                        endYBottom: rightTopY + 13,
                                        totalWidth: w,
                                        baseGradient: LinearGradient(
                                            colors: [
                                                Color(white: 0.20),
                                                MonitorTheme.accentGreen.opacity(0.60)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        isAnimated: true,
                                        shimmerColor: Color(red: 0.40, green: 1.0, blue: 0.65),
                                        progress: progress
                                    )
                                } else {
                                    // Bypass mode: subtle translucent ribbon (dormant, no wave)
                                    AnimatedRibbon(
                                        startX: startX,
                                        startYTop: leftY - 12,
                                        startYBottom: leftY - 2,
                                        endX: endX,
                                        endYTop: rightTopY - 10,
                                        endYBottom: rightTopY + 10,
                                        totalWidth: w,
                                        baseGradient: LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.08),
                                                Color.white.opacity(0.03)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        isAnimated: false,
                                        shimmerColor: .clear,
                                        progress: 0
                                    )
                                }

                                // Bottom Ribbon: Adapter -> System (Mac)
                                AnimatedRibbon(
                                    startX: startX,
                                    startYTop: leftY + 1,
                                    startYBottom: leftY + 18,
                                    endX: endX,
                                    endYTop: rightBottomY - 13,
                                    endYBottom: rightBottomY + 13,
                                    totalWidth: w,
                                    baseGradient: LinearGradient(
                                        colors: [
                                            Color(white: 0.20),
                                            Color(red: 0.22, green: 0.52, blue: 0.95).opacity(0.65)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    isAnimated: true,
                                    shimmerColor: Color(red: 0.45, green: 0.85, blue: 1.0),
                                    progress: progress
                                )
                            } else {
                                // Running on battery: Battery -> Mac ribbon
                                AnimatedRibbon(
                                    startX: startX,
                                    startYTop: leftY - 14,
                                    startYBottom: leftY + 14,
                                    endX: endX,
                                    endYTop: rightBottomY - 13,
                                    endYBottom: rightBottomY + 13,
                                    totalWidth: w,
                                    baseGradient: LinearGradient(
                                        colors: [
                                            MonitorTheme.accentGreen.opacity(0.55),
                                            Color(red: 0.22, green: 0.52, blue: 0.95).opacity(0.55)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    isAnimated: true,
                                    shimmerColor: Color(red: 0.45, green: 0.85, blue: 1.0),
                                    progress: progress
                                )
                            }
                        }
                    }

                    // 2. Mid-flow Labels (Pills) - Completely STATIC, outside TimelineView
                    if flow.isConnected {
                        flowPill(
                            text: flow.batteryWatts > 0.1 ? formatWatts(flow.batteryWatts) : "Bypass",
                            tint: flow.batteryWatts > 0.1 ? MonitorTheme.accentGreen : Color.white.opacity(0.6),
                            bg: flow.batteryWatts > 0.1 ? MonitorTheme.accentGreen.opacity(0.2) : Color.white.opacity(0.08)
                        )
                        .position(x: (startX + endX) * 0.5, y: (leftY + rightTopY) * 0.5 - 2)

                        flowPill(
                            text: formatWatts(flow.systemWatts),
                            tint: Color(red: 0.45, green: 0.75, blue: 1.0),
                            bg: Color(red: 0.15, green: 0.35, blue: 0.7).opacity(0.25)
                        )
                        .position(x: (startX + endX) * 0.5, y: (leftY + rightBottomY) * 0.5 + 2)
                    } else {
                        flowPill(
                            text: formatWatts(abs(flow.batteryWatts)),
                            tint: MonitorTheme.accentGreen,
                            bg: MonitorTheme.accentGreen.opacity(0.2)
                        )
                        .position(x: (startX + endX) * 0.5, y: (leftY + rightBottomY) * 0.5)
                    }

                    // 3. Left Node (Source) - Completely STATIC, outside TimelineView
                    sourceNode(
                        icon: flow.isConnected ? "powerplug.fill" : "battery.100",
                        value: flow.isConnected ? formatWatts(flow.adapterWatts) : formatWatts(abs(flow.batteryWatts)),
                        tint: flow.isConnected ? Color.white : MonitorTheme.accentGreen
                    )
                    .position(x: leftX, y: leftY)

                    // 4. Right Top Node (Battery Target - Icon Only) - Completely STATIC, outside TimelineView
                    iconNode(
                        icon: flow.batteryWatts > 0.1 ? "battery.100.bolt" : "battery.100",
                        tint: flow.batteryWatts > 0.1 ? MonitorTheme.accentGreen : Color.white.opacity(0.5)
                    )
                    .position(x: rightX, y: rightTopY)

                    // 5. Right Bottom Node (Mac System Target - Icon Only) - Completely STATIC, outside TimelineView
                    iconNode(
                        icon: "laptopcomputer",
                        tint: Color(red: 0.45, green: 0.75, blue: 1.0)
                    )
                    .position(x: rightX, y: rightBottomY)
                }
            }
        }
    }

    private func flowPill(text: String, tint: Color, bg: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color(white: 0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(tint.opacity(0.35), lineWidth: 0.75)
                    )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 3, y: 1)
    }

    private func sourceNode(icon: String, value: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(MonitorTheme.primaryText)
                .lineLimit(1)
        }
        .frame(width: 62, height: 44)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(white: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 4, y: 2)
    }

    private func iconNode(icon: String, tint: Color) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: 44, height: 38)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(white: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 4, y: 2)
    }

    private func formatWatts(_ w: Double) -> String {
        w >= 10 ? String(format: "%.1fW", w) : String(format: "%.2fW", w)
    }
}

/// Smooth cubic Bezier ribbon for flow visualization
private struct RibbonShape: Shape {
    var startX: CGFloat
    var startYTop: CGFloat
    var startYBottom: CGFloat
    var endX: CGFloat
    var endYTop: CGFloat
    var endYBottom: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let dx = endX - startX

        path.move(to: CGPoint(x: startX, y: startYTop))
        path.addCurve(
            to: CGPoint(x: endX, y: endYTop),
            control1: CGPoint(x: startX + dx * 0.45, y: startYTop),
            control2: CGPoint(x: endX - dx * 0.45, y: endYTop)
        )
        path.addLine(to: CGPoint(x: endX, y: endYBottom))
        path.addCurve(
            to: CGPoint(x: startX, y: startYBottom),
            control1: CGPoint(x: endX - dx * 0.45, y: endYBottom),
            control2: CGPoint(x: startX + dx * 0.45, y: startYBottom)
        )
        path.closeSubpath()
        return path
    }
}

/// Ribbon with base gradient and animated energy wave shimmer
private struct AnimatedRibbon: View {
    var startX: CGFloat
    var startYTop: CGFloat
    var startYBottom: CGFloat
    var endX: CGFloat
    var endYTop: CGFloat
    var endYBottom: CGFloat
    var totalWidth: CGFloat

    var baseGradient: LinearGradient
    var isAnimated: Bool = false
    var shimmerColor: Color = .white
    var progress: CGFloat = 0.0

    var body: some View {
        let shape = RibbonShape(
            startX: startX,
            startYTop: startYTop,
            startYBottom: startYBottom,
            endX: endX,
            endYTop: endYTop,
            endYBottom: endYBottom
        )

        ZStack {
            // Base Ribbon
            shape.fill(baseGradient)

            // Flowing Energy Wave (Soft & Gentle)
            if isAnimated && totalWidth > 0 {
                let uStart = startX / totalWidth
                let uEnd = endX / totalWidth
                let waveW: CGFloat = 0.30

                let xCenter = (uStart - waveW) + progress * ((uEnd - uStart) + 2 * waveW)

                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: shimmerColor.opacity(0.06), location: 0.25),
                            .init(color: shimmerColor.opacity(0.35), location: 0.50),
                            .init(color: shimmerColor.opacity(0.06), location: 0.75),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: UnitPoint(x: xCenter - waveW, y: 0.5),
                        endPoint: UnitPoint(x: xCenter + waveW, y: 0.5)
                    )
                )
                .blendMode(.plusLighter)
            }
        }
    }
}

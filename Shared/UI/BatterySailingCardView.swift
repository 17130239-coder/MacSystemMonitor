import SwiftUI

/// Renders the complete Sailing Mode interface featuring the Hysteresis Band controller,
/// hardware capability telemetry, and zero-risk interactive simulation.
struct BatterySailingCardView: View {
    @Bindable var engine: SailingModeEngine = SailingModeEngine.shared
    var currentBatteryPercent: Double = 100.0

    @State private var showingHelpPopover: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar matching AlDente & user screenshot
            headerBar

            // Main Content: Deactivated Capsule OR Active Hysteresis Controller View
            if !engine.isEnabled {
                deactivatedView
            } else {
                activeHysteresisView
            }
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
            Image(systemName: "sailboat.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(engine.isEnabled ? Color.cyan : MonitorTheme.primaryText)

            Text("Sailing Mode")
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
            .help("Learn about Sailing Mode & Hysteresis Band")

            Spacer()

            // Hardware Capability Pill
            capabilityPill

            // Toggle Button
            actionButton
        }
    }

    private var capabilityPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(engine.capabilities.canInhibitCharge ? Color.green : Color.orange)
                .frame(width: 5, height: 5)

            Text(engine.capabilities.activeKeySet.displayName)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(MonitorTheme.secondaryText)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(Color(white: 0.12))
        )
    }

    private var actionButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                engine.toggleEnabled()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: engine.isEnabled ? "power" : "play.fill")
                    .font(.system(size: 9, weight: .bold))

                Text(engine.isEnabled ? "Disable" : "Enable")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(engine.isEnabled ? Color.white : MonitorTheme.secondaryText)
            .background(
                Capsule()
                    .fill(engine.isEnabled ? Color.cyan.opacity(0.3) : Color(white: 0.14))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                engine.isEnabled ? Color.cyan.opacity(0.5) : Color.white.opacity(0.12),
                                lineWidth: 0.75
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Deactivated State (Exact match to uploaded screenshot)

    private var deactivatedView: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    engine.isEnabled = true
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Sailing Mode deactivated.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MonitorTheme.secondaryText)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(white: 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
                        )
                )
            }
            .buttonStyle(.plain)

            Text("Click to activate hysteresis band and protect battery health while plugged in.")
                .font(.system(size: 10))
                .foregroundStyle(MonitorTheme.tertiaryText)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Active Hysteresis Controller View

    private var activeHysteresisView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Visual Hysteresis Band Gauge
            hysteresisGauge

            // Controls: Upper Limit, Lower Limit & Strategy
            HStack(spacing: 12) {
                // Limit controls
                thresholdControls
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 38)
                    .overlay(Color.white.opacity(0.08))

                // Strategy selector
                strategySelector
                    .frame(width: 170)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.11))
            )

            // Simulator Bar / Status Note
            simulatorRow
        }
    }

    // MARK: - Visual Gauge

    private var displaySOC: Double {
        engine.isSimulating ? engine.simulatedSOC : currentBatteryPercent
    }

    private var hysteresisGauge: some View {
        VStack(spacing: 6) {
            // Phase indicator badge
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: phaseIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(phaseColor)

                    Text(engine.currentPhase.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MonitorTheme.primaryText)
                }

                Spacer()

                Text("Intent: \(engine.currentIntent.rawValue)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(phaseColor)
            }

            // Interactive track
            GeometryReader { geo in
                let width = geo.size.width
                let lowerX = max(0, min(width, width * CGFloat(engine.lowerLimit / 100.0)))
                let upperX = max(0, min(width, width * CGFloat(engine.upperLimit / 100.0)))
                let currentX = max(0, min(width, width * CGFloat(displaySOC / 100.0)))

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 10)

                    // Hysteresis Band highlight
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.cyan.opacity(0.22))
                        .frame(width: max(0, upperX - lowerX), height: 10)
                        .offset(x: lowerX)

                    // Current Battery Level fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.6), phaseColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: currentX, height: 10)

                    // Marker for Lower Limit
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 2, height: 16)
                        .offset(x: max(0, lowerX - 1))

                    // Marker for Upper Limit
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 2, height: 16)
                        .offset(x: min(width - 2, upperX - 1))
                }
            }
            .frame(height: 16)

            // Labels under track
            HStack {
                Text("\(Int(engine.lowerLimit))% (Lower)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(MonitorTheme.secondaryText)

                Spacer()

                Text("Current: \(Int(displaySOC))%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseColor)

                Spacer()

                Text("\(Int(engine.upperLimit))% (Upper)")
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(MonitorTheme.secondaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.75)
                )
        )
    }

    private var phaseIcon: String {
        switch engine.currentPhase {
        case .chargingUp: return "bolt.fill"
        case .sailing: return "sailboat.fill"
        case .holding: return "pause.fill"
        case .inactive: return "moon.fill"
        }
    }

    private var phaseColor: Color {
        switch engine.currentPhase {
        case .chargingUp: return Color.green
        case .sailing: return Color.cyan
        case .holding: return Color.blue
        case .inactive: return Color.gray
        }
    }

    // MARK: - Threshold Controls

    private var thresholdControls: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("UPPER LIMIT")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(MonitorTheme.secondaryText)

                HStack(spacing: 4) {
                    Text("\(Int(engine.upperLimit))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(MonitorTheme.primaryText)

                    Stepper("", value: $engine.upperLimit, in: 60...95, step: 5)
                        .labelsHidden()
                        .scaleEffect(0.7)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("LOWER LIMIT")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(MonitorTheme.secondaryText)

                HStack(spacing: 4) {
                    Text("\(Int(engine.lowerLimit))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(MonitorTheme.primaryText)

                    Stepper("", value: $engine.lowerLimit, in: 50...min(90, engine.upperLimit - 1), step: 5)
                        .labelsHidden()
                        .scaleEffect(0.7)
                }
            }

            Text("Band: -\(Int(engine.upperLimit - engine.lowerLimit))%")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.cyan)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.cyan.opacity(0.12)))
        }
    }

    // MARK: - Strategy Selector

    private var strategySelector: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STRATEGY")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(MonitorTheme.secondaryText)

            Picker("", selection: $engine.strategy) {
                Text("🍃 Passive").tag(SailingStrategy.passive)
                Text("⚡️ Active").tag(SailingStrategy.activeDischarge)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(engine.strategy == .passive ? "0% extra cycle wear" : "~10% cycle throughput / loop")
                .font(.system(size: 8.5))
                .foregroundStyle(engine.strategy == .passive ? Color.green : Color.orange)
                .lineLimit(1)
        }
    }

    // MARK: - Simulator Row

    private var simulatorRow: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $engine.isSimulating) {
                HStack(spacing: 4) {
                    Image(systemName: "flask.fill")
                        .font(.system(size: 9))
                    Text("Simulator")
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .foregroundStyle(engine.isSimulating ? Color.cyan : MonitorTheme.secondaryText)
            }
            .toggleStyle(.button)
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(Color(white: 0.13)))

            if engine.isSimulating {
                Slider(value: $engine.simulatedSOC, in: 60...100, step: 1)
                    .tint(.cyan)

                Text("\(Int(engine.simulatedSOC))%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.cyan)
                    .frame(width: 32)
            } else {
                Text(engine.strategy.tradeOffSummary)
                    .font(.system(size: 9.5))
                    .foregroundStyle(MonitorTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Help Popover

    private var helpPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sailboat.fill")
                    .foregroundStyle(Color.cyan)
                Text("About Sailing Mode & Hysteresis")
                    .font(.system(size: 13, weight: .bold))
            }

            Divider()

            Text("Sailing Mode introduces a **hysteresis band** around your target charge limit instead of pinning the battery to a single continuous percentage.")
                .font(.system(size: 11.5))
                .foregroundStyle(MonitorTheme.secondaryText)

            VStack(alignment: .leading, spacing: 6) {
                Text("Key Principles:")
                    .font(.system(size: 11, weight: .bold))

                bulletPoint("1. Upper Threshold (e.g. 80%)", "Charging is inhibited when reached, letting the system operate on external power.")
                bulletPoint("2. Hysteresis Band (e.g. 75% - 80%)", "Prevents hunting/chattering. The system avoids rapid charge-on / charge-off cycles.")
                bulletPoint("3. Passive vs Active Trade-off", "Passive mode incurs zero extra cycle wear. Active discharge forces battery drop but adds ~10% cycle throughput per loop.")
                bulletPoint("4. Dynamic Probing", "SMC keys (CHTE / CH0B) are queried dynamically at runtime to verify firmware capabilities safely.")
            }

            Divider()

            HStack {
                Text("Hardware Probing Status:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MonitorTheme.tertiaryText)
                Spacer()
                Text(engine.capabilities.activeKeySet.rawValue)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.cyan)
            }
        }
        .padding(14)
        .frame(width: 360)
    }

    private func bulletPoint(_ title: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(MonitorTheme.primaryText)
            Text(desc)
                .font(.system(size: 10))
                .foregroundStyle(MonitorTheme.secondaryText)
        }
    }
}

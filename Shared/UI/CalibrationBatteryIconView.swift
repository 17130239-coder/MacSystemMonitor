import SwiftUI

/// Custom vector battery glyphs reproducing the exact iconography of each calibration step.
struct CalibrationBatteryIconView: View {
    var step: CalibrationStep
    var isActive: Bool = false

    private let bodyWidth: CGFloat = 24
    private let bodyHeight: CGFloat = 34
    private let capWidth: CGFloat = 8
    private let capHeight: CGFloat = 3.5

    var body: some View {
        VStack(spacing: 0) {
            // Battery Terminal Cap
            batteryCap

            // Battery Body
            ZStack {
                switch step {
                case .chargeTo100, .chargeTo100Final:
                    fullGreenBattery
                case .dischargeTo10:
                    lowDischargeBattery
                case .holdFor:
                    blueHoldBattery
                case .dischargeTo80:
                    discharge80Battery
                }
            }
            .frame(width: bodyWidth, height: bodyHeight)
        }
        .scaleEffect(isActive ? 1.08 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }

    // MARK: - Cap

    @ViewBuilder
    private var batteryCap: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(capColor)
            .frame(width: capWidth, height: capHeight)
    }

    private var capColor: Color {
        switch step {
        case .chargeTo100, .chargeTo100Final:
            return Color(red: 0.55, green: 0.85, blue: 0.65)
        case .dischargeTo10:
            return Color.white.opacity(0.8)
        case .holdFor:
            return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .dischargeTo80:
            return Color.white.opacity(0.8)
        }
    }

    // MARK: - Step 1 & 3: Full Green (+)

    private var fullGreenBattery: some View {
        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.62, green: 0.90, blue: 0.70),
                        Color(red: 0.45, green: 0.78, blue: 0.55)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.75)
            )
            .overlay(
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(white: 0.15))
            )
            .shadow(color: Color.green.opacity(0.25), radius: 4)
    }

    // MARK: - Step 2: Low Discharge (-)

    private var lowDischargeBattery: some View {
        ZStack(alignment: .bottom) {
            // Outline container
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.75), lineWidth: 1.0)
                )

            // Bottom 25% amber charge fill
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.68, blue: 0.32),
                            Color(red: 0.90, green: 0.55, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: bodyHeight * 0.30)
                .padding(1)
                .overlay(
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color(white: 0.15))
                        .offset(y: bodyHeight * 0.35 - bodyHeight * 0.50)
                )
        }
    }

    // MARK: - Step 4: Blue Hold (||)

    private var blueHoldBattery: some View {
        RoundedRectangle(cornerRadius: 4.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.45, green: 0.75, blue: 1.0),
                        Color(red: 0.25, green: 0.50, blue: 0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.75)
            )
            .overlay(
                Image(systemName: "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
            )
            .shadow(color: Color.blue.opacity(0.35), radius: 4)
    }

    // MARK: - Step 5: Discharge to 80% (Dashed Top + -)

    private var discharge80Battery: some View {
        ZStack(alignment: .bottom) {
            // Background container with dashed top ceiling
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(Color(white: 0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .strokeBorder(
                            Color.white.opacity(0.65),
                            style: StrokeStyle(lineWidth: 1.0, dash: [2.5, 2])
                        )
                )

            // Bottom 80% amber fill
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.68, blue: 0.32),
                            Color(red: 0.90, green: 0.55, blue: 0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: bodyHeight * 0.75)
                .padding(1)
                .overlay(
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Color(white: 0.15))
                )
        }
    }
}

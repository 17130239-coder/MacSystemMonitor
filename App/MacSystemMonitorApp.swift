import SwiftUI
import AppKit

@main
struct MacSystemMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Window("Mac Monitor", id: "main") {
            MainView(monitor: AppModel.shared.monitor)
        }
        .defaultSize(width: 820, height: 460)
        .windowResizability(.contentMinSize)

        Window("Sensor Report", id: "report") {
            SensorReportView(monitor: AppModel.shared.monitor)
        }
        .defaultSize(width: 520, height: 600)

        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(after: .windowList) {
                SensorReportCommand()
                Divider()
                Button("Toggle Float on Top") {
                    let current = UserDefaults.standard.bool(forKey: "isFloatingHUD")
                    UserDefaults.standard.set(!current, forKey: "isFloatingHUD")
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleFloatHUD"), object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { AppModel.shared.start() }
    }

    /// Keep sampling so the desktop widget stays fresh after the window is closed.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct SensorReportCommand: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Sensor Report") { openWindow(id: "report") }
            .keyboardShortcut("r", modifiers: [.command, .shift])
    }
}

struct MainView: View {
    var monitor: SystemMonitor
    @AppStorage("isFloatingHUD") private var isFloating = false

    var body: some View {
        MonitorWidgetView(metrics: monitor.metrics, density: .large)
            .padding(14)
            .frame(minWidth: 540, minHeight: 330)
            .background(Color(white: 0.05))
            .preferredColorScheme(.dark)
            .onAppear { applyWindowLevel() }
            .onChange(of: isFloating) { _, _ in applyWindowLevel() }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleFloatHUD"))) { _ in
                applyWindowLevel()
            }
    }

    private func applyWindowLevel() {
        for window in NSApp.windows where window.title == "Mac Monitor" {
            window.level = isFloating ? .floating : .normal
        }
    }
}

#if DEBUG
#Preview("Main window") {
    MainView(monitor: SystemMonitor())
        .frame(width: 820, height: 460)
}
#endif

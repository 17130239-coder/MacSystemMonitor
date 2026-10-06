import SwiftUI

struct SettingsView: View {
    @AppStorage(AppModel.intervalDefaultsKey) private var seconds = 1.0

    var body: some View {
        Form {
            Picker("Refresh interval", selection: $seconds) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("5 seconds").tag(5.0)
            }
            Text("The desktop widget is refreshed by macOS on its own schedule (about once a minute at best), regardless of this setting.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .onChange(of: seconds) { _, new in
            AppModel.shared.setRefreshInterval(seconds: new)
        }
    }
}

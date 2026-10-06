# MacSystemMonitor

A lightweight, native macOS system monitoring application and WidgetKit widget designed specifically for Apple Silicon Macs (M1/M2/M3/M4).

Displays all key system telemetry in **one compact card**:

* CPU Usage % and Temperature °C
* GPU Usage % and Temperature °C
* RAM Usage % and Used / Total GB
* Battery % and Temperature °C
* SSD Temperature °C
* Fan RPM (or `Fanless`)
* Detected Mac model, chip, and calculated thermal status (`Normal` / `Warm` / `Hot`)

All data comes from real macOS system interfaces. **No simulated or fake values are used anywhere.** When an interface is unavailable on a specific Mac, the UI displays `N/A` (or `Fanless` for fanless models) without crashing or degrading other sensors.

---

## Visual Design

The UI is built strictly with SwiftUI and uses native macOS materials, SF Pro system fonts, and a clean white-on-dark theme with an Apple system-green accent (`#30D158`), inspired by Apple's Battery widget.

* **Usage bars** for CPU, GPU, and RAM match the displayed integer percentages exactly.
* **No icons, emoji, charts, or decorative gradients.** Data is the primary focus.
* **Adaptive layout**: the same SwiftUI view renders in the main application window (resizable) and across WidgetKit families (`systemSmall`, `systemMedium`, `systemLarge`).

```
┌─────────────────────────────────────────────┐
│ MacBook Pro · Apple M1 Pro           Normal │
├──────────────────┬──────────────────┬───────┤
│ CPU              │ GPU              │ RAM   │
│ 27%              │ 24%              │ 82%   │
│ █████░░░░░        │ ████░░░░░░        │████████░ │
│ 56°C              │ 52°C              │13.1/16│
├──────────────────┼──────────────────┼───────┤
│ Battery          │ SSD              │ Fan   │
│ 80%              │ 36°C             │ 1592  │
│ 33°C             │                  │ RPM   │
└──────────────────┴──────────────────┴───────┘
```

---

## Sensor APIs and Technical Investigation

Apple Silicon hardware access differs substantially from Intel Macs. The table below details the exact API used for each metric and its Apple Silicon support:

| Metric | API / Interface | Apple Silicon Status | Permissions / Privileges | Fallback / Unavailable Behavior |
|--------|----------------|----------------------|--------------------------|---------------------------------|
| **CPU Usage %** | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Supported on all Apple Silicon Macs. Sums ticks across all performance (P) and efficiency (E) cores. | None (standard user process). | Reports `.error` if the kernel call fails; renders `N/A`. |
| **CPU Temperature** | Primary: `AppleSMC` keys `Tp**` / `Te**`<br>Fallback: `IOHIDEventSystemClient` (`PMU tdie*`) | Supported on M1, M2, M3, M4. Discovers available core sensors and averages them. | Unsandboxed user process; **no root required**. | Falls back to HID PMU sensors. If both are blocked, renders `N/A`. |
| **GPU Usage %** | `IOAccelerator` IORegistry entry: `PerformanceStatistics["Device Utilization %"]` | Supported on Apple Silicon (`AGXAccelerator`). Matches Activity Monitor's GPU history. | None (public IOKit registry). | Renders `N/A` if no accelerator exposes statistics. |
| **GPU Temperature** | `AppleSMC` keys `Tg**` | Supported on Apple Silicon Macs exposing GPU thermal sensors in SMC. | Unsandboxed user process; **no root required**. | Renders `N/A` if absent. Does *not* estimate from CPU. |
| **RAM Usage** | `host_statistics64(HOST_VM_INFO64)` and `ProcessInfo.physicalMemory` | Supported on all Macs. Interpreted as `(internal − purgeable) + wired + compressed` to match Activity Monitor's "Memory Used" (reclaimable cache is not counted as used). | None. | Reports `.error`; renders `N/A`. |
| **Battery %** | `IOKit.ps` (`IOPSCopyPowerSourcesInfo`) | Supported on all battery-powered Macs. | None. | `N/A` on desktop Macs (Mac mini, Mac Studio, Mac Pro, iMac). |
| **Battery Temp** | Primary: `IOHIDEventSystemClient` (`gas gauge battery`)<br>Fallback: `AppleSMC` `TB*T` or `AppleSmartBattery["Temperature"]` | Supported on Apple Silicon MacBooks. | Unsandboxed user process; **no root required**. | `N/A` on desktop Macs or if the sensor is unavailable. |
| **SSD Temp** | Primary: `IOHIDEventSystemClient` (`NAND CH* temp`)<br>Fallback: `AppleSMC` `TH0*` | Supported on Apple Silicon with accessible NAND thermal diodes. Takes the maximum across channels. | Unsandboxed user process; **no root required**. | `N/A` when the system does not expose NAND channels. |
| **Fan RPM** | `AppleSMC` keys `FNum` and `F<n>Ac` | Supported on Macs with fans. Averages RPM across all detected fans. | Unsandboxed user process; **no root required**. | Distinguishes between **`Fanless`** (e.g. MacBook Air, verified via `FNum == 0` or model detection) and `N/A` (fan exists but sensor unreadable). |

---

## Apple Silicon Limitations and Architecture

### 1. App Sandbox vs. Hardware Sensors
Apple's App Sandbox strictly forbids user-space clients from opening the `AppleSMC` iOService and communicating with the `IOHIDEventSystemClient` thermal usage pages. For this reason:
* **The main application target is deliberately NOT App Sandboxed.** It runs as a standard, unprivileged user-space application (no `sudo`/root required).
* **The WidgetKit extension MUST be App Sandboxed** by macOS requirement.
* To bridge this limitation, the main app runs the real-time monitoring engine and periodically writes an atomic JSON snapshot into an App Group container (`SnapshotStore`). The widget reads this snapshot. If the main app has not run recently, the widget displays an "Open app" status instead of fabricating values.

### 2. WidgetKit Refresh Frequency
WidgetKit does not support continuous 1-second refreshes. macOS budgets timeline reloads and throttles them to preserve battery life. The main application is therefore the **source of truth for real-time (1 Hz) monitoring**, while the desktop widget serves as a near-real-time glance updated periodically.

### 3. Dynamic Hardware Detection
* Total physical memory is queried via `ProcessInfo.processInfo.physicalMemory` (never hardcoded to 16 GB).
* The Mac model identifier is queried via `sysctl hw.model` and mapped to marketing names (e.g., MacBook Pro, MacBook Air, Mac mini, Mac Studio).
* The chip name is retrieved via `machdep.cpu.brand_string` (e.g., "Apple M1 Pro").
* Fan presence is verified dynamically using SMC key `FNum`. MacBook Air models report `0` fans and the UI displays **Fanless**, avoiding misleading `0 RPM` or `N/A` readings.

### 4. Thermal Status Evaluation
Status (`Normal` / `Warm` / `Hot`) is calculated from available temperature readings using:
* **Per-sensor thresholds**:
  * CPU: Warm ≥ 75 °C, Hot ≥ 90 °C
  * GPU: Warm ≥ 75 °C, Hot ≥ 90 °C
  * Battery: Warm ≥ 38 °C, Hot ≥ 45 °C
  * SSD: Warm ≥ 70 °C, Hot ≥ 80 °C
* **Exponential Moving Average (EMA)** smoothing (`smoothing = 0.25`) to prevent transient spikes from triggering state changes.
* **Hysteresis** (3.0 °C drop required to de-escalate) to eliminate visual flapping between states.

---

## Project Structure

```
MacSystemMonitor/
├── project.yml                     # XcodeGen project specification
├── App/
│   ├── MacSystemMonitorApp.swift   # Main app entry, window management
│   ├── AppModel.swift              # App-level coordinator & Widget snapshot publisher
│   ├── SettingsView.swift          # Refresh interval preferences
│   ├── SensorReportView.swift      # Diagnostics window (Cmd+Shift+R)
│   ├── AppIcon.icns                # Multi-resolution macOS icon bundle
│   ├── Assets.xcassets/            # AppIcon asset catalog (16x16 to 1024x1024)
│   ├── Info.plist
│   └── MacSystemMonitor.entitlements
├── Shared/
│   ├── Models/
│   │   ├── SensorValue.swift       # SensorAvailability enum & SensorValue<T> model
│   │   ├── HardwareInfo.swift      # Machine identity & discovered sensor list
│   │   ├── SystemMetrics.swift     # Complete snapshot data struct
│   │   ├── SystemStatus.swift      # StatusEvaluator with EMA & hysteresis
│   │   └── SystemMetrics+Display.swift # Formatted text & bar fraction helpers
│   ├── Services/
│   │   ├── SMCConnection.swift     # AppleSMC client (non-root)
│   │   ├── TemperatureProbes.swift # IOHID & SMC low-level probes
│   │   ├── SensorDiscoveryService.swift # Dynamic sensor enumeration & classification
│   │   ├── TemperatureService.swift     # Multi-sensor aggregation
│   │   ├── CPUService.swift        # Mach host_processor_info tick calculator
│   │   ├── GPUService.swift        # IOAccelerator registry utilization
│   │   ├── MemoryService.swift     # host_statistics64 Activity Monitor model
│   │   ├── BatteryService.swift    # IOPowerSources & thermal sensors
│   │   ├── FanService.swift        # Fan count, presence, and RPM averaging
│   │   └── HardwareInfoService.swift # sysctl model and chip detection
│   ├── Monitoring/
│   │   ├── SystemSampler.swift     # Composition root & background SamplingEngine actor
│   │   ├── SystemMonitor.swift     # Observable @MainActor view model
│   │   └── SnapshotStore.swift     # App Group file-based snapshot exchange
│   ├── UI/
│   │   ├── MonitorTheme.swift      # Dark theme & Apple-green accent
│   │   ├── UsageBar.swift          # Custom capsule usage bar
│   │   ├── MetricCard.swift        # Grid cell view
│   │   ├── HeaderView.swift        # Machine name & status indicator
│   │   └── MonitorWidgetView.swift # Unified adaptive monitoring view
│   └── Utilities/
│       ├── ByteFormatter.swift     # GiB memory formatting
│       └── TemperatureFormatter.swift # Whole °C & raw unit conversions
├── Widget/
│   ├── MacSystemMonitorWidget.swift # WidgetKit extension (small, medium, large)
│   ├── Info.plist
│   └── MacSystemMonitorWidget.entitlements
├── PreviewSupport/
│   └── PreviewMetrics.swift        # DEBUG-only mock data for SwiftUI previews
└── Tests/
    ├── Mocks.swift                 # Test doubles (no hardware required)
    ├── CPUAndMemoryTests.swift     # CPU tick math & memory pressure logic
    ├── TemperatureTests.swift      # Conversion, classification, aggregation
    ├── FanBatteryStatusTests.swift # Fanless behavior, hysteresis, thresholds
    └── SamplerAndFormattingTests.swift # End-to-end sampler & snapshot tests
```

---

## Build Instructions

### Requirements
* macOS 14.0 or later
* Xcode 15+ / Xcode 16+ with macOS SDK
* [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
* Apple Silicon Mac (M1, M2, M3, M4)

### Building and Testing

1. **Generate the Xcode project**:
   ```bash
   cd /Users/andynguyen/workspace/MacSystemMonitor
   xcodegen generate
   ```

2. **Run the unit test suite**:
   ```bash
   xcodebuild -project MacSystemMonitor.xcodeproj \
              -scheme MacSystemMonitor \
              -destination 'platform=macOS,arch=arm64' \
              -allowProvisioningUpdates test
   ```
   All 60 unit tests run in isolation using test doubles and execute in under 0.1 seconds.

3. **Build the application**:
   ```bash
   xcodebuild -project MacSystemMonitor.xcodeproj \
              -scheme MacSystemMonitor \
              -configuration Release \
              -destination 'platform=macOS,arch=arm64' \
              -allowProvisioningUpdates build
   ```

4. **Launch the application**:
   ```bash
   open /Users/andynguyen/Library/Developer/Xcode/DerivedData/MacSystemMonitor-*/Build/Products/Debug/MacSystemMonitor.app
   ```

5. **Open the Sensor Report diagnostics**:
   Inside the running app, press **Cmd+Shift+R** (or choose *Window → Sensor Report*) to inspect every detected sensor, its raw interface, and its current reading.

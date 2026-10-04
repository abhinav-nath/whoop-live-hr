# WHOOP Live HR

**Your heart rate, a glance away.**

A small native macOS app that puts live heart-rate readings from your WHOOP in the menu bar. Click the heart to see recent readings, a chart, and connection details.

<img width="358" height="464" alt="image" src="https://github.com/user-attachments/assets/55b3b3ca-dd75-4c6b-ab4f-cc9aff0444be" />

Built with Swift, SwiftUI, AppKit, CoreBluetooth, and Swift Charts. No third-party dependencies or WHOOP API credentials required.

## Features

- **Live BPM in the menu bar** — a fixed-width display with monospaced digits keeps neighboring items from shifting.
- **Five-minute history** — a chart with minimum, average, and maximum heart rate.
- **Automatic connection** — discovers a nearby WHOOP and retries after a disconnect.
- **Stale-reading protection** — clears the displayed BPM when updates stop for roughly 10–12 seconds.
- **Connection details** — device name, signal strength, status, and the last reading’s time.
- **Menu-bar only** — no main window or Dock icon.

## Requirements

- A Mac with Bluetooth Low Energy support.
- **macOS 27.0 or later**, as currently configured in the Xcode project. Earlier versions have not been validated.
- Xcode with a macOS SDK that supports the configured deployment target.
- A WHOOP with **Heart Rate Broadcast** enabled.

The app is currently built and run from source.

## Get started

### 1. Enable heart-rate broadcast

In the WHOOP mobile app, open **Device Settings** and enable **Heart Rate Broadcast**. Keep your WHOOP nearby and wear it so it can produce readings. See [WHOOP’s overview of heart-rate broadcasting](https://www.whoop.com/us/en/thelocker/10-whoop-features-you-need-to-know/) for more context.

### 2. Open the project

```sh
git clone https://github.com/abhinav-nath/whoop-live-hr.git
cd whoop-live-hr
open whoop-live-hr.xcodeproj
```

### 3. Run on your Mac

1. Select the **WhoopLiveHR** scheme and **My Mac** destination in Xcode.
2. If Xcode requests signing configuration, select your development team under **Signing & Capabilities**.
3. Press **⌘R** to build and run.
4. Allow Bluetooth access when macOS asks.

A heart icon appears in the menu bar. The app starts searching automatically and displays BPM when readings arrive. Click the icon to open the popover; choose **Quit** there to close the app.

## How it works

```text
WHOOP heart-rate broadcast
          ↓ Bluetooth Low Energy
WhoopHeartRateMonitor
          ↓ HeartRatePacketParser decodes the measurement
Published BPM, history, and connection state
          ↓
Menu-bar display + SwiftUI popover
```

The monitor first scans for the standard Bluetooth Heart Rate service (`180D`). If it has not found a device after five seconds, it falls back to scanning all nearby BLE peripherals. It identifies candidates by a name containing `WHOOP` or starting with `WHP`.

After connecting, it subscribes to Heart Rate Measurement notifications (`2A37`). The parser supports both 8-bit and little-endian 16-bit BPM values and rejects incomplete measurements. UI updates follow published state changes rather than polling for the latest BPM.

Disconnected devices trigger another scan after two seconds. While connected, signal strength refreshes every ten seconds.

## Privacy

Heart-rate readings stay in memory on your Mac and disappear when the app exits. The app does not save reading history to disk or send it to a server. It connects directly to the WHOOP over Bluetooth and does not sign in to your WHOOP account.

Connection diagnostics, including device names and signal strength, are printed to the development console.

## Troubleshooting

| What you see | What to check |
| --- | --- |
| **Scanning for WHOOP…** or **Searching for WHOOP…** | Confirm Heart Rate Broadcast is enabled, your WHOOP is charged and nearby, and Bluetooth is on. |
| **Bluetooth permission denied** | Enable the app under **System Settings → Privacy & Security → Bluetooth**, then relaunch it. |
| **Bluetooth is off** | Turn Bluetooth on. The app starts scanning when Bluetooth becomes available. |
| Connected, but BPM shows **--** | The app is waiting for a reading, or the previous reading has expired. Check that your WHOOP is worn and broadcasting. |
| Service discovery or subscription fails | Recheck broadcasting and relaunch the app. These failures do not currently trigger an automatic retry. |
| No Dock icon or main window | This is expected. Look for the heart in the menu bar. |

For more detail while developing, inspect the Xcode console for discovery, connection, and notification messages.

## Project layout

| File | Responsibility |
| --- | --- |
| [`WhoopLiveHRApp.swift`](WhoopLiveHR/WhoopLiveHRApp.swift) | SwiftUI entry point and app-delegate integration. |
| [`AppDelegate.swift`](WhoopLiveHR/AppDelegate.swift) | Owns the monitor and menu-bar controller; shuts down Bluetooth on exit. |
| [`WhoopHeartRateMonitor.swift`](WhoopLiveHR/WhoopHeartRateMonitor.swift) | BLE discovery, connection, notifications, reading history, and timers. |
| [`HeartRatePacketParser.swift`](WhoopLiveHR/HeartRatePacketParser.swift) | Decodes BPM from a measurement without depending on CoreBluetooth. |
| [`StatusBarController.swift`](WhoopLiveHR/StatusBarController.swift) | AppKit status item, Combine subscriptions, and popover hosting. |
| [`StatusPopoverView.swift`](WhoopLiveHR/StatusPopoverView.swift) | SwiftUI reading display, chart, statistics, and device details. |

### Build from the command line

For a local compile check without code signing:

```sh
xcodebuild \
  -project whoop-live-hr.xcodeproj \
  -scheme WhoopLiveHR \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

This checks compilation; validating discovery, permissions, reconnection, and live readings requires running the app with a physical WHOOP. There is no committed automated test target yet.

## Current limitations

- Device selection is automatic and name-based; there is no device picker or saved device preference.
- History is pruned when new readings arrive. If the stream stops, the chart can retain readings older than five minutes even though the current BPM is cleared.
- History is session-only; there is no export or persistence.
- Launch at login and an in-app troubleshooting panel are not implemented yet.
- The source uses macOS-only AppKit APIs, although the Xcode project still contains unused iOS and visionOS platform settings.

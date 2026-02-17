# tvOS Simulator Verification

## Prerequisites
- Xcode installed (`xcodebuild` available)
- XcodeGen installed (`xcodegen` available)
- At least one tvOS simulator runtime installed
- `Vendor/TVVLCKit.xcframework` is present (raw TS playback dependency)

## Build Verification Commands
Run from repo root:

```bash
./scripts/fetch-tvvlckit.sh
xcodegen generate
xcrun simctl list devices available | rg "tvOS"
xcodebuild -project JapanTV.xcodeproj -scheme JapanTV -destination 'platform=tvOS Simulator,name=<DEVICE_NAME>' build
```

Replace `<DEVICE_NAME>` with an available tvOS simulator (example: `Apple TV`).

## Launch Verification Commands
After a successful build:

```bash
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug-appletvsimulator/JapanTV.app" | head -n 1)
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.example.japantv
```

## Manual Runtime Check (Simulator)
1. Launch the app in tvOS simulator from Xcode.
2. Open `Settings` tab.
3. Verify default URL is `http://raspberrypi:40772`.
4. Press `Test Connection`.
5. If your Mirakurun host differs, update URL to your server and re-test.
6. Open `Channels` tab.
7. Confirm rows show channel name, logo (when available), and now/next text.
8. Select a channel and confirm the player opens as fullscreen.
9. Open `Programs` tab and confirm you can browse programs for selected channel.
10. Press the Siri Remote `Menu` button and confirm it returns to the channels list.
11. Confirm player status line changes (`Opening`, `Buffering`, `Playing`) during live playback.

## Verification Record
- Date: 2026-02-17
- Dependency setup:
  - `./scripts/fetch-tvvlckit.sh 3.7.2`
  - Result: `TVVLCKit installed at: /Volumes/My Shared Files/japan-tv/Vendor/TVVLCKit.xcframework`
- Build verification:
  - `xcodebuild -project JapanTV.xcodeproj -scheme JapanTV -destination 'platform=tvOS Simulator,name=Apple TV' build`
  - Result: `BUILD SUCCEEDED`
- Launch verification:
  - `xcrun simctl install booted <JapanTV.app>`
  - `xcrun simctl launch booted com.example.japantv`
  - Result: Launch success (`com.example.japantv: 38906`)

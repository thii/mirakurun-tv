# JapanTV

A tvOS client for Mirakurun with a channel tile grid, program browsing, and fullscreen live playback.

## Features
- Channel browser in a tvOS-focused tile grid UI
- Channel logos from Mirakurun service logo API
- Program browser for any channel
- Fullscreen playback from channel selection
- Remote `Menu` button exits player and returns to channels
- Configurable Mirakurun server URL in-app (default: `http://raspberrypi:40772`)
- Optional HLS URL template override
- Default direct raw TS playback using `TVVLCKit`

## Tech Stack
- SwiftUI (tvOS)
- Async/await networking
- XcodeGen project generation (`project.yml`)
- `TVVLCKit.xcframework` for MPEG-TS playback

## Requirements
- macOS with Xcode (tvOS simulator runtime installed)
- XcodeGen
- `curl` and `tar` (for dependency fetch script)
- Apple Developer account/team only if installing on a physical Apple TV

## Quick Start (Simulator)
From repo root:

```bash
./scripts/fetch-tvvlckit.sh
xcodegen generate
xcodebuild -project JapanTV.xcodeproj -scheme JapanTV -destination 'platform=tvOS Simulator,name=Apple TV' build
```

Then run from Xcode, or install/launch via `simctl`:

```bash
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Debug-appletvsimulator/JapanTV.app" | head -n 1)
xcrun simctl boot "Apple TV" || true
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted com.example.japantv
```

## In-App Settings
Open the `Settings` tab:
- `Server URL`: Mirakurun base URL
- `Use HLS Override Template`: enable/disable URL-template playback override
- `HLS Template`: supports placeholders
  - `{serviceId}`
  - `{networkId}`
  - `{channelType}`
  - `{channel}`
  - `{base}`
- `Test Connection`: checks `GET /api/version`
- `Reset to Defaults`: restores app defaults

## Mirakurun over Tailscale
If your Mirakurun server is reached through Tailscale, configure `Server URL` using the server's Tailscale identity.

1. Confirm both your development Mac and Mirakurun host are online in the same tailnet:

```bash
tailscale status
```

2. Choose one of these URL formats for the server:
- MagicDNS machine name: `http://<machine-name>:40772`
- Full tailnet DNS name: `http://<machine-name>.<tailnet>.ts.net:40772`
- Tailscale IP: `http://100.x.y.z:40772`

3. Verify connectivity from macOS before opening the app:

```bash
curl http://<machine-name>:40772/api/version
```

4. In JapanTV `Settings`, set `Server URL` to the same value and press `Test Connection`.

## Playback Behavior
- Default mode: direct raw TS stream from Mirakurun endpoint
  - `/api/services/{id}/stream`
- Playback engine: `TVVLCKit` (`VLCMediaPlayer`)
- Optional mode: HLS override template from settings

## Local Signing and Install to Apple TV
Team details are stored locally and not committed.

1. Create local signing/deploy config:

```bash
./scripts/configure-local-signing.sh --team-id <TEAM_ID> --team-name "<TEAM_NAME>" --device "<APPLE_TV_NAME_OR_UDID>"
```

2. Build, install, and launch:

```bash
./scripts/install-to-apple-tv.sh
```

Local-only generated files:
- `config/Signing.local.xcconfig`
- `.local/apple-tv.env`

Both are gitignored.

## Verification Checklist
- Build succeeds for tvOS simulator
- `Settings` tab can test Mirakurun connection
- `Channels` tab shows a channel tile grid with logos when available
- Selecting a channel opens fullscreen playback
- Pressing `Menu` returns to the channel grid
- `Programs` tab can browse schedules per channel

## Project Layout
- `JapanTV/` app source
- `JapanTV/Networking/` API client, endpoints, settings store, playback URL resolver
- `JapanTV/ViewModels/` channels/programs view models
- `JapanTV/Views/` channels/programs/player/settings views
- `scripts/` helper scripts (dependency fetch, local signing setup, device install)
- `config/` shared/local signing xcconfig
- `docs/` implementation plans and verification notes
- `Vendor/` third-party artifacts and license texts

## Troubleshooting
- `xcodebuild` cannot read `.xcodeproj`:
  - Regenerate the project with `xcodegen generate`
- Missing `TVVLCKit.xcframework`:
  - Run `./scripts/fetch-tvvlckit.sh`
- Playback unavailable:
  - Verify server URL in settings
  - Check Mirakurun tuner/resource availability
  - If needed, enable HLS override with a valid template

## License Notes
`TVVLCKit` license texts are included under `Vendor/`.

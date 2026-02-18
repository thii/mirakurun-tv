# JapanTV

A tvOS client for Mirakurun to browse channels/programs and watch live TV.

## What It Does
- Shows channels in a tvOS tile grid
- Shows program schedules for selected channels
- Plays live streams in fullscreen using `TVVLCKit`
- Lets you configure Mirakurun `Server URL` in-app

## Requirements
- macOS + Xcode (with tvOS simulator runtime)
- `xcodegen`
- `curl` and `tar`
- Apple Developer team only for physical Apple TV install

## Quick Start (Simulator)
From repo root:

```bash
./scripts/fetch-tvvlckit.sh
xcodegen generate
xcodebuild -project JapanTV.xcodeproj -scheme JapanTV -destination 'platform=tvOS Simulator,name=Apple TV' build
```

Launch from Xcode, then in app `Settings`:
- Set `Server URL` (Mirakurun base URL)
- Toggle `Show Subtitles` (`OFF` by default; enables subtitle tracks available in TS stream)
- Use `Test Connection` (`GET /api/version`)
- If the stream subtitle codec is unsupported by bundled `TVVLCKit` (for example ARIB `arba`), the player now shows an in-player warning.

## Install to Physical Apple TV
```bash
./scripts/configure-local-signing.sh --team-id <TEAM_ID> --team-name "<TEAM_NAME>" --device "<APPLE_TV_NAME_OR_UDID>"
./scripts/install-to-apple-tv.sh
```

Generated local files are gitignored:
- `config/Signing.local.xcconfig`
- `.local/apple-tv.env`

## Common Troubleshooting
- Project/build issues: run `xcodegen generate`
- Missing `TVVLCKit`: run `./scripts/fetch-tvvlckit.sh`
- Playback issues: verify `Server URL` and Mirakurun status

## Project Structure
- `JapanTV/`: app source
- `JapanTV/Networking/`: API client and playback URL logic
- `JapanTV/ViewModels/`: channels/programs state
- `JapanTV/Views/`: channels/programs/player/settings screens
- `scripts/`: setup/install helpers
- `docs/`: deeper notes and verification details

## More Documentation
- `docs/local-signing-and-apple-tv-install.md`
- `docs/tvos-simulator-verification.md`
- `docs/raw-ts-direct-playback.md`

## License
`TVVLCKit` licenses are in `Vendor/`.

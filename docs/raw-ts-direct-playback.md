# Raw TS Direct Playback (VLC)

## Why
Mirakurun exposes live streams as raw MPEG-TS (`/api/services/{id}/stream`).
This app now uses `TVVLCKit` for direct TS decode/playback on tvOS.

## Dependency Source
- VideoLAN package: `TVVLCKit.xcframework`
- Script: `scripts/fetch-tvvlckit.sh`

## Setup
Run from repo root:

```bash
./scripts/fetch-tvvlckit.sh
xcodegen generate
xcodebuild -project JapanTV.xcodeproj -scheme JapanTV -destination 'platform=tvOS Simulator,name=Apple TV' build
```

## Notes
- `project.yml` links and embeds `Vendor/TVVLCKit.xcframework`.
- The binary framework is intentionally gitignored because it is large.
- Keep `Vendor/TVVLCKit-COPYING.txt` with your distribution for license compliance.

## Runtime
- `PlayerView` now uses `VLCRawTSPlayerView`.
- Status text is shown (`Opening`, `Buffering`, `Playing`, etc.) from VLC state callbacks.
- `Settings` includes `Show Subtitles` (default `OFF`), which enables subtitle tracks present in the TS stream when turned on.
- If VLC reports an unsupported subtitle codec (for example ARIB `arba`), the player shows a subtitle-unavailable warning overlay.

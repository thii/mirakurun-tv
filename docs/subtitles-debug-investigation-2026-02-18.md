# Subtitles Debug Investigation (February 18, 2026)

## Goal
- Debug why subtitles were not visible on tvOS simulator and physical Apple TV.
- Verify subtitle setting behavior (default OFF, visible behavior when ON).

## Reproduction
1. Enabled subtitles in app settings.
2. Opened live channel playback (raw TS stream from Mirakurun).
3. Observed no rendered subtitles on-screen.

## Hypotheses Investigated
1. Subtitle toggle state was not persisted or not wired into player.
2. Player was not selecting subtitle ES track.
3. Stream lacked subtitle data.
4. tvOS VLC build could not decode subtitle codec in this TS stream.

## Key Debugging Steps and Findings

### 1) Settings + wiring
- Added persisted setting `settings.subtitlesEnabled` with default `false`.
- Added Settings UI toggle (`Show Subtitles`).
- Verified the player receives `showsSubtitles` and applies subtitle preference.

### 2) Track discovery and selection
- Added subtitle track diagnostics in `VLCRawTSPlayerView`.
- Confirmed subtitle track appears and is selected:
  - `Selected subtitle track id=304 name='ARIB subtitles - [Japanese]'`

### 3) Codec-level failure in TVVLCKit
- Captured simulator runtime logs while playing live TS stream.
- Observed VLC identifies ARIB subtitle ES but cannot decode it:
  - `=> pid 304 has now es fcc=arba`
  - `Codec \`arba' (ARIB subtitles (A-profile)) is not supported.`
  - `VLC could not decode the format "arba" (ARIB subtitles (A-profile))`

### 4) `decode=1` stream-side test
- Tested Mirakurun stream with `decode=1` as a workaround.
- Result: ARIB subtitle codec behavior remained unsupported in current tvOS VLC runtime.

## Root Cause
- Subtitles are present in the TS stream and the app does select the subtitle track.
- The bundled TVVLCKit build on tvOS cannot decode ARIB subtitle codec (`arba`) for this stream.
- Therefore, subtitles do not render even when subtitle track selection is correct.

## Implemented Product Behavior
1. Added user-facing subtitle toggle (default OFF).
2. Kept subtitle track auto-selection logic for available TS subtitle tracks.
3. Added subtitle status signaling in player:
   - If unsupported ARIB subtitle is detected (track metadata and/or VLC debug line), show:
   - `Subtitles unavailable: ARIB subtitles are not supported by the current TVVLCKit build.`
4. Added docs updates in README and raw TS playback doc.

## Verification Evidence

### Build and tests
- Command:
  - `xcodebuild -project JapanTV.xcodeproj -scheme JapanTV -destination 'platform=tvOS Simulator,name=Apple TV' build`
- Result:
  - `** BUILD SUCCEEDED **`

- Command:
  - `xcodebuild test -project JapanTV.xcodeproj -scheme JapanTV -destination 'platform=tvOS Simulator,name=Apple TV'`
- Result:
  - `** TEST SUCCEEDED **`

### Runtime subtitle diagnostics (simulator)
- Log capture command:
  - `xcrun simctl spawn booted log stream --level debug --style compact --predicate 'process == "JapanTV" AND (eventMessage CONTAINS[c] "Subtitles" OR eventMessage CONTAINS[c] "ARIB" OR eventMessage CONTAINS[c] "arba")'`
- Key lines observed:
  - `looked up value 1 for key settings.subtitlesEnabled`
  - `[Subtitles] Selected subtitle track id=304 name='ARIB subtitles - [Japanese]'`
  - `[VLCSub] Codec \`arba' (ARIB subtitles (A-profile)) is not supported.`
  - `[VLCSub] VLC could not decode the format "arba" (ARIB subtitles (A-profile))`
  - `[Subtitles] Status: Subtitles unavailable: ARIB subtitles are not supported by the current TVVLCKit build.`

## Constraints / Remaining Gap
- This environment had no physical Apple TV attached (`xcrun xctrace list devices` listed simulators only), so physical device rerun could not be executed here.
- Functional rendering of ARIB subtitles remains blocked by decoder support in the current TVVLCKit build; current change makes this explicit to users instead of failing silently.


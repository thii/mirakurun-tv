# Hybrid Mirakurun tvOS Client Plan

## Goal
Build a tvOS app that uses Mirakurun JSON APIs for metadata (channels, logos, programs) and uses direct Mirakurun TS playback (`/api/services/{id}/stream`) with VLC (`TVVLCKit`).

## Product Requirements
- Configurable Mirakurun server address with default: `http://raspberrypi:40772`
- Channel table/list with:
  - Channel/service name
  - Channel logo (if available)
  - Program now/next summary
- Program browsing UI:
  - Browse any channel
  - Show program list sorted by start time
- Playback screen:
  - Stream selected channel

## Architecture
- `SettingsStore`
  - Persists server URL in `UserDefaults`
  - Exposes normalized URL values for networking
- `MirakurunClient` (async/await)
  - `GET /api/version` for connection check
  - `GET /api/services`
  - `GET /api/programs?networkId=...&serviceId=...`
- `MirakurunEndpointBuilder`
  - Constructs API, logo, and stream URLs from the server URL
- `PlaybackURLResolver`
  - Resolves TS stream URL from selected service and server URL
- `VLCRawTSPlayerView`
  - Uses `VLCMediaPlayer` from `TVVLCKit` for raw TS playback
- `ChannelsViewModel`
  - Loads services
  - Loads and caches now/next program snippets per service
- `ProgramsViewModel`
  - Loads services
  - Loads programs for selected service

## UI
- `TabView`
  - `Channels`
  - `Programs`
  - `Settings`
- `Channels`
  - list rows with logo, service name, now/next program text
- `Programs`
  - split-style channel selection and per-channel program list
- `Settings`
  - Mirakurun base URL text field
  - reset to defaults
  - test connection action

## Delivery Phases
1. Scaffold tvOS SwiftUI app and data models
2. Implement networking + settings persistence
3. Implement channels/programs browsing and player view
4. Document simulator verification and run build verification

## Known Risks
- Raw TS playback depends on bundled libVLC binary compatibility
- Mirakurun tuner limits can return `503` when unavailable
- Large EPG payloads can impact load time; fetch per-service first

## Mitigations
- Clear error messages in UI for connection/playback failures
- Lazy/on-demand program fetch per selected service

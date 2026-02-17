# AGENTS.md

## Project Scope
This repository contains a tvOS client for Mirakurun.

## Development Expectations
- Prefer small, reviewable commits.
- Keep networking and UI logic separated.
- When adding new API calls, update docs in `docs/` if behavior changes.

## tvOS Navigation Verification
- For tvOS navigation/back behavior changes, verify `Menu` button handling before completion.
- Validate that pressing `Menu` from nested screens (for example Program details) returns to the previous in-app screen and does not terminate the app unexpectedly.
- When possible, use reproducible simulator verification (for example UI tests with `XCUIRemote.shared.press(.menu)`), and include the verification command/output in commit evidence.
- For this repository, run `xcodebuild test -project JapanTV.xcodeproj -scheme JapanTV -destination 'platform=tvOS Simulator,name=Apple TV' -only-testing:JapanTVUITests/ProgramsMenuNavigationUITests/testMenuReturnsToProgramsChannelListFromDetail` after any Programs navigation change.

## Commit Message Requirements
All commit messages must include concrete debugging and investigation details.

### Required sections
Use this structure in commit messages:

```text
<short summary in plain language (no Conventional Commit prefix)>

Context
- Why this change was needed.

Changes
- What changed in code and config.

Investigation
- What was investigated.
- Relevant hypotheses considered.
- Key observations from logs/traces.

Debugging Evidence
- Commands executed.
- Important output excerpts (errors/status/results).
- How failures were reproduced and how they were resolved.

Verification
- Exact verification steps.
- Simulator/device/build commands.
- Result (pass/fail) and remaining gaps.
```

### Rules
- Do not write generic commit messages like "fix bug".
- Do not use Conventional Commit prefixes like `feat:`, `fix:`, `chore:`, `docs:`, or similar `<type>:` labels.
- Include command lines used for debugging (for example: `xcodebuild ...`, `xcrun simctl ...`).
- Include status codes, error strings, and affected endpoints when relevant.
- If a bug cannot be fully resolved, state what is still unknown and the next debugging step.

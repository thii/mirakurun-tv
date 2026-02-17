# AGENTS.md

## Project Scope
This repository contains a tvOS client for Mirakurun.

## Development Expectations
- Prefer small, reviewable commits.
- Keep networking and UI logic separated.
- When adding new API calls, update docs in `docs/` if behavior changes.

## Commit Message Requirements
All commit messages must include concrete debugging and investigation details.

### Required sections
Use this structure in commit messages:

```text
<type>: <short summary>

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
- Include command lines used for debugging (for example: `xcodebuild ...`, `xcrun simctl ...`).
- Include status codes, error strings, and affected endpoints when relevant.
- If a bug cannot be fully resolved, state what is still unknown and the next debugging step.

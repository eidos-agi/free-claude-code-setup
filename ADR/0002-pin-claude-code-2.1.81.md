# ADR 0002 — Pin `@anthropic-ai/claude-code@2.1.81`

**Date:** 2026-04-24
**Status:** Accepted

## Decision

`bootstrap.sh` installs `@anthropic-ai/claude-code@2.1.81` exactly. No `npm update`, no latest, no minor-version-allowed.

## Context

Starting with `claude-code@2.1.83`, the package ships as a Bun-compiled standalone ELF binary with a `.bun` section at `0x1000` alignment. WSL1's Linux syscall emulation layer cannot map this segment layout and refuses the executable with `Exec format error`. Confirmed in [anthropics/claude-code#38788](https://github.com/anthropics/claude-code/issues/38788), [#39385](https://github.com/anthropics/claude-code/issues/39385), [#40546](https://github.com/anthropics/claude-code/issues/40546).

2.1.81 and earlier are plain Node scripts with `#!/usr/bin/env node` shebangs and run fine anywhere Node does.

## Alternatives considered

- **Upgrade to 2.1.83+** — broken on WSL1. Would work on WSL2 but see ADR 0001.
- **Use the Windows `claude.cmd` via WSL interop** — available as fallback in `bin/claude-nim`, works, but adds Windows/WSL boundary crossing per invocation (slower, messier env propagation). Preferred to be absent-not-primary.
- **Fork claude-code and rebuild without Bun packaging** — maintenance nightmare; fights upstream.

## Consequences

- No automatic security updates to claude-code. Periodically check upstream for a WSL1-compatible re-release.
- `npm update` at the user level would silently regress to a broken state.
- `bootstrap.sh` must explicitly pin and verify the installed version.
- V1-V5 validations assume 2.1.81 behavior; if upstream ships a fix and we bump, re-run full suite.

## Re-evaluate if

- WSL2 becomes viable on Shadow (ADR 0001).
- Upstream addresses the Bun ELF alignment (unlikely — it's a WSL1 limitation, not claude-code's bug).
- We move off WSL entirely.

## Source

`claude-insights/claude-code/wsl1-pin-2.1.81.md`.

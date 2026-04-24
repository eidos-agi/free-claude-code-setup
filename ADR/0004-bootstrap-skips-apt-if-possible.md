# ADR 0004 — bootstrap.sh skips `apt-get install` if required packages are already present

**Date:** 2026-04-24
**Status:** Accepted

## Decision

`bootstrap.sh` checks for each required command (currently just `curl` and `git`) before touching apt. If both are present, skip `apt-get update && apt-get install` entirely.

## Context

WSL1 can't run systemd. When `apt-get install` runs (even for unrelated packages), dpkg's post-install phase tries to `dpkg --configure -a`, which attempts to configure systemd if it's in a half-configured state. On WSL1 that fails with `Failed to take /etc/passwd lock: Invalid argument` — systemd's init step can't complete without PID 1 actually being systemd.

Once this failure happens, the apt run aborts halfway through and the bootstrap is wedged.

V5 (reproducibility) exercised this: a fresh `cnimtest` user on a host where systemd was already held and functional still triggered the trap because `build-essential` wasn't installed and triggered dpkg configure.

## Alternatives considered

- **Always `apt-get install` the full list** — wedges on WSL1 hosts with any systemd misconfiguration, which is essentially all of them at some point.
- **`dpkg --configure -a || true` before install** — doesn't fix the systemd case, just masks the signal.
- **Pre-install all possible dependencies at WSL provision time** — machine-level work, outside bootstrap's user-level scope.

## The minimalism that makes this work

Our real dependencies are tiny:
- `curl` — downloads nvm and uv installers
- `git` — clones the two repos
- `python3` — always on Ubuntu, never needs install
- Everything else (node, npm, uv's Python, proxy deps) comes via nvm + uv, which don't touch apt

`build-essential` was originally in the list to support native node modules. `claude-code@2.1.81` is pure JS; no native compile. Dropped.

## Consequences

- On a truly fresh Ubuntu where `curl` or `git` is missing, we still do apt. That hits the systemd trap if the machine hasn't been properly prepared.
- Bootstrap failure in that case prints an explicit message pointing at `claude-insights/wsl/systemd-hold.md`.
- The "machine-level" prerequisites (WSL1 install, Tailscale DNS fix, systemd hold) remain manual — documented in `PLAN.md` §Cold-start rebuild steps 1-3.

## Re-evaluate if

- WSL1 ever gains systemd support (unlikely) or we move to WSL2 (ADR 0001).
- A required dep gets added that's not available via nvm/uv.

## Source

Discovered during V5 validation; fix is in `bootstrap.sh` step [2/13].

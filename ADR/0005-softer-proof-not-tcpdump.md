# ADR 0005 — V2 uses softer composed proofs, not tcpdump/iptables

**Date:** 2026-04-24
**Status:** Accepted

## Decision

V2 (no-Anthropic-leak validation) proves its claim by composing three evidences rather than by capturing packets on the wire:

1. **Positive:** proxy log shows `POST /v1/messages 200 OK` for each scenario
2. **Negative:** `/proc/net/tcp*` snapshot right after each scenario has no entries matching Anthropic's IPv4/6 prefixes (160.79.104.0/23 or 2607:6bc0::/32)
3. **Isolation:** `~/claude-nim-home/.claude/.credentials.json` never acquires real OAuth content

## Context

The gold-standard proof would be tcpdump on all interfaces + iptables OUTPUT rules dropping to Anthropic netblocks during the test. That definitively answers "did any packets go to Anthropic?"

Problems:
- tcpdump isn't installed on base WSL1 Ubuntu; `apt install tcpdump` risks the systemd trap (ADR 0004).
- iptables rules on WSL1 don't always apply to all sockets (per-session kernel table quirks).
- Writing firewall rules mid-test touches machine state the user didn't explicitly sign off on.

The user explicitly chose "softer proof is fine" when offered the tradeoff.

## Why the softer proof is still convincing

- Positive proof (proxy log shows POST) is airtight: if the request reached our local proxy, by definition it didn't reach Anthropic.
- Negative proof (no Anthropic IP in /proc/net/tcp) catches the failure mode where SOME request leaks to Anthropic in parallel — even if the primary POST hits the proxy, any side-channel auth probe to Anthropic would appear.
- Isolation proof (credential file stays empty) catches the pernicious case where claude-code would have used cached OAuth had the launcher not redirected HOME.

Each evidence alone is imperfect; composed, they cover the known failure modes.

## Alternatives considered

- **tcpdump-based proof** — rejected on WSL1 constraints (above) and user preference.
- **iptables block-and-verify** — rejected for same reasons + destructive to machine state.
- **Add unit tests in the proxy repo that verify env-var handling in `bin/claude-nim`** — considered, skipped. The launcher is short and its behavior is exercised by V2's live runs; unit tests wouldn't add meaningfully.

## Consequences

- V2 can miss a genuine leak if the leak happens at a moment not captured by the /proc/net/tcp snapshot (snapshots are taken after each scenario completes, so sub-second leaks during the request itself might miss).
- If a new auth pitfall ever silently leaks to Anthropic during a scenario that ALSO happens to reach the proxy successfully, V2's positive proof alone would mask it.
- We accept this risk because the three known pitfalls are all addressed at the launcher level (ADR 0003) and V2 exercises each.

## Re-evaluate if

- A real leak is ever observed that V2 missed.
- tcpdump becomes available without the apt trap.
- WSL2 becomes viable and we can run full tcpdump reliably.

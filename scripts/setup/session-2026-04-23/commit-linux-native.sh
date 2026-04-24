#!/bin/bash
set -eu
REPO=/root/repos/free-claude-code-setup
SRC=/mnt/c/Users/Shadow/repos/free-claude-code-setup/new-bin

# Install updated launcher + new CLAUDE.md + check-nim + corrected PLAN.md + logs
cp "$SRC/claude-nim"      "$REPO/bin/claude-nim"
cp "$SRC/check-nim"       "$REPO/bin/check-nim"
cp "$SRC/check-nim.bat"   "$REPO/bin/check-nim.bat"
cp "$SRC/CLAUDE.md"       "$REPO/CLAUDE.md"
cp "$SRC/PLAN.md"         "$REPO/PLAN.md"
cp "$SRC/logs/2026-04-23-open-issues.md" "$REPO/logs/2026-04-23-open-issues.md"
cp "$SRC/commit-linux-native.sh" "$REPO/scripts/setup/session-2026-04-23/commit-linux-native.sh"
chmod +x "$REPO/bin/claude-nim" "$REPO/bin/check-nim" "$REPO/scripts/setup/session-2026-04-23/commit-linux-native.sh"

# Symlink check-nim into /usr/local/bin so it's callable from anywhere
ln -sf "$REPO/bin/check-nim" /usr/local/bin/check-nim

cd "$REPO"
git add bin/claude-nim bin/check-nim bin/check-nim.bat CLAUDE.md PLAN.md logs/2026-04-23-open-issues.md scripts/setup/session-2026-04-23/commit-linux-native.sh
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "Prefer Linux-native Claude Code 2.1.81; add CLAUDE.md and check-nim

Correction: previously documented that Linux claude-code could not run
on WSL1 because the binary errored with 'Exec format error'. That was
only true for 2.1.83+ which ships as a Bun-compiled native ELF binary
whose segment alignment WSL1's loader rejects. 2.1.81 is a plain Node
script and runs fine on WSL1 with Node 20. Refs:
  anthropics/claude-code#38788, #39385, #40546

Verified end-to-end: \`claude -p 'ping'\` with ANTHROPIC_BASE_URL set
to the proxy produces LINUX_OK response and a \`POST /v1/messages?beta=true
200 OK\` entry in /tmp/nim-proxy.log.

Changes:
- bin/claude-nim: prefer /root/.nvm/versions/node/*/bin/claude when
  present, with isolated HOME=/root/claude-nim-home; fall back to
  Windows claude.cmd via interop otherwise.
- CLAUDE.md (new, at repo root): briefing doc auto-loaded when a
  Claude session cwd's into this repo. Points to PLAN.md for detail,
  lists the non-derivable quirks (Shadow PC, Tailscale DNS, WSL1
  version pin, three auth pitfalls), and tells future Claude what
  NOT to do.
- bin/check-nim (+ .bat wrapper): multi-section health check with
  colored pass/fail output. Probes proxy, launcher PATH resolution,
  upstream repo+env state, isolated profile, recent traffic.
- Symlinked /usr/local/bin/check-nim.
- logs/2026-04-23-open-issues.md: added 'Correction — 2026-04-24'.
- PLAN.md: rewrote the 'Why Windows Claude Code, not Linux' section."

echo "--- git log ---"
git log --oneline | head -12
echo
echo "--- check-nim self-run ---"
/usr/local/bin/check-nim 2>&1 || true

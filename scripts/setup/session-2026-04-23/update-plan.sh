#!/bin/bash
set -eu
REPO=$HOME/repos/free-claude-code-setup
SRC=/mnt/c/Users/Shadow/repos/free-claude-code-setup/new-bin

cp "$SRC/PLAN.md" "$REPO/PLAN.md"
# Also archive this script for posterity
cp "$SRC/update-plan.sh" "$REPO/scripts/setup/session-2026-04-23/update-plan.sh"
chmod +x "$REPO/scripts/setup/session-2026-04-23/update-plan.sh"

cd "$REPO"
git add PLAN.md scripts/setup/session-2026-04-23/update-plan.sh
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "PLAN.md: add Verification / health checks section

Previously the cold-start section had a one-liner smoke test, but nowhere
explained *what* the checks prove or *why* you'd run them. Added a proper
Verification section with three tiered checks:

1. curl probe → is the proxy listening? (no API usage)
2. claude-nim --version from a fresh shell → is the whole launcher
   pipeline wired (PATH, proxy startup, claude.exe, env vars) without
   spending an API request?
3. claude-nim -p → end-to-end inference round-trip works? (1 request)

Each check explains the failure modes it uncovers. Also explains *why*
a fresh shell matters for check #2 (registry-based User PATH, live shells
cache at startup)."

echo "--- git log ---"
git log --oneline | head -10

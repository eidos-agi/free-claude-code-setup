#!/bin/bash
set -eu
REPO=/root/repos/free-claude-code-setup
SRC=/mnt/c/Users/Shadow/repos/free-claude-code-setup/new-bin

cp "$SRC/claude-nim.bat" "$REPO/bin/claude-nim.bat"
mkdir -p "$REPO/logs"
cp "$SRC/logs/2026-04-23-open-issues.md" "$REPO/logs/2026-04-23-open-issues.md"
cp "$SRC/commit-logs.sh" "$REPO/scripts/setup/session-2026-04-23/commit-logs.sh"
chmod +x "$REPO/scripts/setup/session-2026-04-23/commit-logs.sh"

cd "$REPO"
git add bin/claude-nim.bat logs/2026-04-23-open-issues.md scripts/setup/session-2026-04-23/commit-logs.sh
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "Add logs/2026-04-23-open-issues.md; tee proxy stdout to file

Three things:
1. claude-nim.bat now pipes uvicorn stdout+stderr to /tmp/nim-proxy.log
   via tee, so proxy traffic is auditable without needing to find the
   minimized WSL window. Check with: wsl cat /tmp/nim-proxy.log | tail -40
2. Added logs/2026-04-23-open-issues.md recording what's fixed (quoting
   bug, ss-based listening, cached OAuth bypass via USERPROFILE) and
   what's still ambiguous (whether current Sonnet-branded responses are
   real Anthropic or kimi-k2 impersonation). Documents the next diagnostic
   step needed to settle it.
3. Preserves this commit script for posterity per session archival
   convention."

git log --oneline | head -10

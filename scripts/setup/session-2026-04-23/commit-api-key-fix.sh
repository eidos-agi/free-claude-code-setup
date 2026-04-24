#!/bin/bash
set -eu
REPO=$HOME/repos/free-claude-code-setup
SRC=/mnt/c/Users/Shadow/repos/free-claude-code-setup/new-bin

cp "$SRC/claude-nim.bat" "$REPO/bin/claude-nim.bat"
cp "$SRC/claude-nim"     "$REPO/bin/claude-nim"
chmod +x "$REPO/bin/claude-nim"
cp "$SRC/logs/2026-04-23-open-issues.md" "$REPO/logs/2026-04-23-open-issues.md"
cp "$SRC/commit-api-key-fix.sh" "$REPO/scripts/setup/session-2026-04-23/commit-api-key-fix.sh"
chmod +x "$REPO/scripts/setup/session-2026-04-23/commit-api-key-fix.sh"

cd "$REPO"
git add bin/claude-nim.bat bin/claude-nim logs/2026-04-23-open-issues.md scripts/setup/session-2026-04-23/commit-api-key-fix.sh
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "Launchers: explicitly clear ANTHROPIC_API_KEY to force proxy routing

Resolved open issue #4 from logs/2026-04-23-open-issues.md.

Diagnostic that settled it: ran claude -p in PowerShell with USERPROFILE
isolation + ANTHROPIC_BASE_URL + ANTHROPIC_AUTH_TOKEN. Proxy log showed
only GET / 401 probes, no POST /v1/messages - i.e., Claude Code probed
but didn't use the proxy. Adding one more env var explicitly,
ANTHROPIC_API_KEY='', flipped this: next invocation produced
POST /v1/messages?beta=true HTTP/1.1 200 OK entries in the proxy log.

Root cause: Claude Code's auth precedence prefers ANTHROPIC_API_KEY over
ANTHROPIC_AUTH_TOKEN even when the former is defined-but-empty (or
inherited as 'set' from some ambient source). Explicit empty-string
assignment in the launcher defeats the precedence check and the
AUTH_TOKEN path wins.

Both launchers updated. Logs/open-issues doc updated with the
resolution narrative so this isn't re-rediscovered."

echo '--- git log ---'
git log --oneline | head -10

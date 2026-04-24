#!/bin/bash
set -e
REPO=$HOME/repos/free-claude-code-setup
SRC=/mnt/c/Users/Shadow/repos/free-claude-code-setup/new-bin

cp "$SRC/claude-nim"     "$REPO/bin/claude-nim"
cp "$SRC/stop-nim-proxy" "$REPO/bin/stop-nim-proxy"
chmod +x "$REPO/bin/claude-nim" "$REPO/bin/stop-nim-proxy"

cd "$REPO"
git add bin/claude-nim bin/stop-nim-proxy
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "Fix listening check: use curl HTTP probe instead of ss

WSL1 /proc/net/tcp is per-session — ss in a fresh WSL shell cannot see
sockets bound by processes in other WSL sessions, even though they share
the Windows network stack. Probe with curl instead — any non-000 HTTP
status from the proxy root (it returns 401) means the server is up.

stop-nim-proxy also switches to 'wsl --shutdown' as the surest portable
way to halt a proxy started from any WSL session."

git log --oneline | head -5
echo "--- listening() self-test ---"
code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://localhost:8082/ 2>/dev/null) || code=000
echo "HTTP code from http://localhost:8082/: $code"
if [ "$code" != "000" ] && [ -n "$code" ]; then
    echo "PASS: proxy is reachable"
else
    echo "FAIL: proxy not reachable"
fi

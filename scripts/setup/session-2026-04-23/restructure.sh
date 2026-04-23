#!/bin/bash
set -eu
REPO=/root/repos/free-claude-code-setup
SRC=/mnt/c/Users/Shadow/repos/free-claude-code-setup/new-bin
cd "$REPO"

echo "=== create new layout ==="
mkdir -p bin scripts/setup

echo "=== install new bin/ files ==="
cp "$SRC/claude-nim"         bin/claude-nim
cp "$SRC/stop-nim-proxy"     bin/stop-nim-proxy
cp "$SRC/claude-nim.bat"     bin/claude-nim.bat
cp "$SRC/stop-nim-proxy.bat" bin/stop-nim-proxy.bat
chmod +x bin/claude-nim bin/stop-nim-proxy

echo "=== install README.md ==="
cp "$SRC/README.md" README.md

echo "=== move historical scripts ==="
# Use git mv when tracked, plain mv when not
for f in phase2.sh phase2b.sh; do
    [ -f "$f" ] && git mv "$f" "scripts/setup/$f" 2>/dev/null || true
done
# move-to-wsl.sh was never committed; just move it
[ -f "$SRC/../move-to-wsl.sh" ] && cp "$SRC/../move-to-wsl.sh" scripts/setup/move-to-wsl.sh
chmod +x scripts/setup/*.sh 2>/dev/null || true

echo "=== remove stale root-level .bat copies (now in bin/) ==="
git rm -f claude-nim.bat stop-nim-proxy.bat 2>/dev/null || rm -f claude-nim.bat stop-nim-proxy.bat

echo "=== final tree ==="
find . -type f -not -path "./.git/*" | sort

echo "=== stage and commit ==="
git add .
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "Restructure: bin/ for launchers, scripts/setup/ for history, README.md

- Add bin/claude-nim and bin/stop-nim-proxy (bash, WSL-native)
- Fix claude-nim.bat: remove setlocal EnableDelayedExpansion
  (was getting mangled by PowerShell's & operator on bat files).
  Replaces the retry counter with a simple for /l loop.
- Move phase2.sh, phase2b.sh into scripts/setup/ (historical)
- Add README.md with layout + quick-start
"

echo "=== git log ==="
git log --oneline

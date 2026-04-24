#!/bin/bash
set -e
DEST=$HOME/repos/free-claude-code-setup
SRC=/mnt/c/Users/Shadow/repos/free-claude-code-setup

mkdir -p "$DEST"
cd "$DEST"

for f in PLAN.md env.template phase2.sh phase2b.sh claude-nim.bat stop-nim-proxy.bat; do
    if [ -f "$SRC/$f" ]; then
        cp "$SRC/$f" "$DEST/"
        echo "copied: $f"
    fi
done

cat > .gitignore <<'GIEOF'
# secrets / env files
.env
*.env.local

# install logs (regenerable, not portable)
*.log
*.err

# os noise
.DS_Store
Thumbs.db
GIEOF

git init -q
git add .
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "Initial commit: NIM proxy setup scaffolding"

echo "=== repo state ==="
ls -la
echo "--- git log ---"
git log --oneline
echo "--- git status ---"
git status

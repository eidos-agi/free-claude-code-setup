#!/bin/bash
# Phase 2 setup inside WSL Ubuntu (run as root)
export HOME=/root
cd "$HOME"

echo "=== nvm install ==="
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null bash 2>&1 | tail -10

echo "=== load nvm ==="
export NVM_DIR="$HOME/.nvm"
. "$NVM_DIR/nvm.sh"
nvm --version

echo "=== installing node LTS ==="
nvm install --lts 2>&1 | tail -5
node --version
npm --version

echo "=== installing claude-code ==="
npm install -g @anthropic-ai/claude-code 2>&1 | tail -5
which claude
claude --version

echo "=== repos dir ==="
mkdir -p "$HOME/repos"
ls -la "$HOME/repos"

echo "=== persistent env (~/.bashrc.nim) ==="
cat > "$HOME/.bashrc.nim" <<'RCEOF'
# uv
export PATH="$HOME/.local/bin:$PATH"
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
RCEOF

grep -q "bashrc.nim" "$HOME/.bashrc" || echo "source ~/.bashrc.nim" >> "$HOME/.bashrc"

echo "=== PHASE 2 DONE ==="

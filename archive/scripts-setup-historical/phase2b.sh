#!/bin/bash
# Phase 2b: swap broken Node 24 for Node 20 (WSL1-compatible)
export HOME=/root
cd /root

echo "=== HOME=$HOME ==="
echo "=== nvm dir contents ==="
ls -la $HOME/.nvm/versions/node/ 2>&1

echo "=== removing node 24 ==="
rm -rf $HOME/.nvm/versions/node/v24.15.0
ls -la $HOME/.nvm/versions/node/ 2>&1

echo "=== explicit NVM_DIR ==="
export NVM_DIR=$HOME/.nvm
echo "NVM_DIR=$NVM_DIR"
ls "$NVM_DIR/nvm.sh"

echo "=== sourcing nvm ==="
. $HOME/.nvm/nvm.sh
echo "type nvm:"
type nvm | head -2

echo "=== installing node 20 ==="
nvm install 20 2>&1 | tail -10
nvm alias default 20

echo "=== verify ==="
node --version
npm --version

echo "=== install claude-code (best effort) ==="
npm install -g @anthropic-ai/claude-code 2>&1 | tail -10
which claude
ls $HOME/.nvm/versions/node/*/bin/claude 2>&1 || echo "no linux claude installed"

echo "=== DONE ==="

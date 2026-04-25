#!/bin/bash
# V5: Clean-machine reproducibility via bootstrap.sh on a fresh user.
#
# Creates a scratch user, runs bootstrap.sh as that user, verifies claude-nim
# works, then tears the user down. Proves the setup isn't secretly dependent
# on dshanklin's accumulated state.
#
# Requires: root (or passwordless sudo) — we create/delete a user.
# NIM_API_KEY env var must be set (the test can't prompt for it).

set -u
VALIDATION="V5 reproducibility"
TEST_USER="${REPRO_TEST_USER:-cnimtest}"
SETUP_REPO="/home/dshanklin/repos/free-claude-code-setup"

echo "=== $VALIDATION ==="

# Preflight — must be root to useradd; must have NIM_API_KEY
if [ "$(id -u)" != "0" ]; then
  if ! sudo -n true 2>/dev/null; then
    echo "  [SKIP] requires root/sudo for useradd; run via 'sudo -n bash 05-reproducibility.sh'"
    exit 2
  fi
  SUDO="sudo"
else
  SUDO=""
fi

if [ -z "${NIM_API_KEY:-}" ]; then
  # Try to reuse dshanklin's key
  if [ -f /home/dshanklin/repos/free-claude-code-setup/proxy/.env ]; then
    NIM_API_KEY=$(grep '^NVIDIA_NIM_API_KEY=' /home/dshanklin/repos/free-claude-code-setup/proxy/.env | sed 's/NVIDIA_NIM_API_KEY=//; s/^"//; s/"$//')
    echo "  (borrowed NIM_API_KEY from dshanklin's .env)"
  fi
fi
if [ -z "${NIM_API_KEY:-}" ]; then
  echo "  [SKIP] NIM_API_KEY not set"
  exit 2
fi

BOOTSTRAP="$SETUP_REPO/bootstrap.sh"
[ -f "$BOOTSTRAP" ] || { echo "  [FAIL] bootstrap.sh not found at $BOOTSTRAP"; exit 1; }

cleanup() {
  echo "--- cleanup: removing $TEST_USER ---"
  sudo pkill -u "$TEST_USER" 2>/dev/null || true
  sleep 1
  sudo userdel -r "$TEST_USER" 2>/dev/null || true
  sudo rm -f "/etc/sudoers.d/$TEST_USER-bootstrap" 2>/dev/null || true
}
trap cleanup EXIT

# Ensure cnimtest doesn't already exist
if id "$TEST_USER" >/dev/null 2>&1; then
  echo "  [WARN] $TEST_USER already exists, removing first"
  sudo userdel -r "$TEST_USER" 2>/dev/null || true
fi

echo "--- create scratch user $TEST_USER ---"
sudo useradd -m -s /bin/bash "$TEST_USER" || { echo "  [FAIL] useradd failed"; exit 1; }
# Grant sudo (without password) — bootstrap needs it for apt + /usr/local/bin symlink
echo "$TEST_USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$TEST_USER-bootstrap" >/dev/null
echo "  created $TEST_USER (home: /home/$TEST_USER)"

echo
echo "--- run bootstrap.sh as $TEST_USER ---"
T0=$(date +%s)
# bootstrap needs access to the script — copy it in so testbot has a local copy
TESTBOT_HOME="/home/$TEST_USER"
sudo cp "$BOOTSTRAP" "$TESTBOT_HOME/bootstrap.sh"
sudo chown "$TEST_USER:$TEST_USER" "$TESTBOT_HOME/bootstrap.sh"
sudo chmod +x "$TESTBOT_HOME/bootstrap.sh"

# Stage world-readable clone sources in /tmp so cnimtest can reach them.
# (In a real "fresh machine" test, the URLs would be public github remotes —
# we use file:// to avoid network flakiness.)
STAGE_DIR=$(mktemp -d -p /tmp bootstrap-src-XXXXXX)
sudo chmod 755 "$STAGE_DIR"
sudo cp -r /home/dshanklin/repos/free-claude-code-setup "$STAGE_DIR/"
sudo cp -r /home/dshanklin/repos/free-claude-code-setup/proxy       "$STAGE_DIR/"
# Make .env unreadable by cnimtest (force use of NIM_API_KEY env var, which is
# what a fresh-machine install would do)
sudo rm -f "$STAGE_DIR/free-claude-code-setup/proxy/.env"
sudo chmod -R a+rX "$STAGE_DIR"
# Git 2.35+ refuses clones from repos owned by other users — chown to cnimtest.
sudo chown -R "$TEST_USER:$TEST_USER" "$STAGE_DIR"
LOCAL_SETUP_URL="file://$STAGE_DIR/free-claude-code-setup"
LOCAL_PROXY_URL="file://$STAGE_DIR/free-claude-code"
echo "  staged clone sources at $STAGE_DIR"

# Augment cleanup to remove staging
ORIG_CLEANUP=$(declare -f cleanup)
cleanup() {
  eval "$ORIG_CLEANUP"
  sudo rm -rf "$STAGE_DIR" 2>/dev/null || true
}

BOOT_LOG="/tmp/bootstrap-test-$$.log"
sudo -u "$TEST_USER" -H bash -lc "
  export NIM_API_KEY='$NIM_API_KEY'
  export SETUP_REPO_URL='$LOCAL_SETUP_URL'
  export PROXY_REPO_URL='$LOCAL_PROXY_URL'
  bash ~/bootstrap.sh
" > "$BOOT_LOG" 2>&1
BOOT_EC=$?
T1=$(date +%s)

echo "  bootstrap exit: $BOOT_EC   took: $((T1-T0))s"
echo "  last 25 lines of bootstrap log:"
tail -25 "$BOOT_LOG" | sed 's/^/    /'
echo

FAIL=0
if [ "$BOOT_EC" -ne 0 ]; then
  echo "  [FAIL] bootstrap returned non-zero"
  FAIL=1
fi

# Independent verification — try claude-nim as testbot
echo "--- verify: claude-nim as $TEST_USER ---"
VERIFY_LOG="/tmp/bootstrap-verify-$$.log"
sudo -u "$TEST_USER" -H bash -lc "
  export NVM_DIR=\"\$HOME/.nvm\"
  . \"\$NVM_DIR/nvm.sh\" >/dev/null 2>&1
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  timeout 90 claude-nim --dangerously-skip-permissions -p 'one word: works' --model claude-haiku-4-20250514 2>&1
" > "$VERIFY_LOG" 2>&1
VERIFY_EC=$?
echo "  verify exit: $VERIFY_EC"
echo "  response:"
head -c 400 "$VERIFY_LOG" | sed 's/^/    /'
echo

# Success criterion: verify returned exit 0 AND response content is non-trivial.
# We can't rely on testbot's proxy log because the launcher reuses an existing
# proxy (bound to :8082 by any user) and logs to that user's $HOME.
VERIFY_CONTENT=$(grep -vE '^\[claude-nim\]|^Warning:|^$' "$VERIFY_LOG" | head -c 200)
if [ "$VERIFY_EC" -eq 0 ] && [ -n "$VERIFY_CONTENT" ]; then
  echo "  response content from model: $VERIFY_CONTENT"
else
  echo "  [FAIL] verify exit=$VERIFY_EC, content='$VERIFY_CONTENT'"
  FAIL=1
fi

# Extra confidence: claude-nim command is actually in testbot's PATH
if ! sudo -u "$TEST_USER" -i bash -c 'command -v claude-nim' >/dev/null 2>&1; then
  echo "  [FAIL] claude-nim not in testbot's PATH"
  FAIL=1
else
  echo "  [PASS] claude-nim resolves for testbot"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "=== $VALIDATION: PASS (bootstrap worked on fresh user) ==="
  exit 0
else
  echo "=== $VALIDATION: FAIL ==="
  exit 1
fi

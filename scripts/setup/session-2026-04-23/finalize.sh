#!/bin/bash
set -eu
REPO=/root/repos/free-claude-code-setup
WINDOWS=/mnt/c/Users/Shadow/repos/free-claude-code-setup
NEW=$WINDOWS/new-bin

echo "=== archive install logs into repo (historical diagnostic) ==="
mkdir -p "$REPO/scripts/setup/install-logs"
# Keep the meaningful ones; skip the staging files
for f in dism.log vmp.log vmp-status.log hvplat.log bcd.log; do
    if [ -f "$WINDOWS/$f" ]; then
        cp "$WINDOWS/$f" "$REPO/scripts/setup/install-logs/$f"
        echo "archived: $f"
    fi
done

echo "=== install updated PLAN.md ==="
cp "$NEW/PLAN.md" "$REPO/PLAN.md"

cd "$REPO"
git add PLAN.md scripts/setup/install-logs/
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "Rewrite PLAN.md as operations manual; archive install logs

PLAN.md is now organized for permanent reference, not as a todo list:
- Quick reference table at top
- Architecture diagram with the WSL1/Shadow/Windows decisions explained
- File layout of every relevant path, including the symlinks and stubs
- Machine-specific quirks section (Shadow PC, Tailscale DNS, pinned resolv.conf,
  held systemd, uv-managed Python 3.14) — the non-derivable facts
- Cold-start rebuild procedure for reproducing this setup from scratch
- Troubleshooting section for the common failure modes we hit
- History of what blocked us and what we explicitly didn't do, with reasons

Also archives the DISM/VMP/BCD logs from original WSL feature-enable into
scripts/setup/install-logs/ so they persist with the repo after the Windows
setup folder is deleted."

echo "=== git log ==="
git log --oneline | head -10

echo "=== tree ==="
find . -type f -not -path "./.git/*" | sort

echo "=== DONE ==="

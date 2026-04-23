#!/bin/bash
set -eu
REPO=/root/repos/free-claude-code-setup
WINDOWS=/mnt/c/Users/Shadow/repos/free-claude-code-setup
NEW=$WINDOWS/new-bin

echo "=== archive session artifacts (2026-04-23 setup session) ==="
DEST="$REPO/scripts/setup/session-2026-04-23"
mkdir -p "$DEST"

# Helper scripts used during the bring-up session
for f in restructure.sh commit-fix.sh finalize.sh preserve-history.sh; do
    if [ -f "$NEW/$f" ]; then
        cp "$NEW/$f" "$DEST/$f"
        chmod +x "$DEST/$f"
        echo "archived: $f"
    fi
done

# A narrative note explaining what this directory is
cat > "$DEST/README.md" <<'EOF'
# Session artifacts — 2026-04-23

Scratch scripts used during the original NIM proxy bring-up session. Preserved
as historical record of how this setup was built.

Not meant to be re-run. Most assume specific source paths that no longer exist
(e.g. `/mnt/c/Users/Shadow/repos/free-claude-code-setup/new-bin/`). Read them
for "how did we get here", not as live tooling.

| File | What it did |
|---|---|
| `restructure.sh` | Reorganized the initial flat layout into `bin/` + `scripts/setup/` |
| `commit-fix.sh` | Installed the curl-based `listening()` fix + committed |
| `finalize.sh` | Archived DISM/VMP/BCD logs + installed the rewritten PLAN.md |
| `preserve-history.sh` | This script — archived these session artifacts themselves |

See `PLAN.md` → "History / setup narrative" section for the human-readable
version.
EOF
echo "archived: README.md"

cd "$REPO"
git add scripts/setup/session-2026-04-23/
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "Archive 2026-04-23 session scripts under scripts/setup/session-2026-04-23/

Preserves the scratch scripts that restructured the repo, installed the
PLAN.md rewrite, and archived install logs. Not re-runnable — kept purely
as archaeology so future-me can understand how the layout came to be."

echo "=== git log ==="
git log --oneline | head -10

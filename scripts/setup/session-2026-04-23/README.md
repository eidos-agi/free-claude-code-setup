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

# proxy/ — vendored as a subtree

This directory is a `git subtree --squash` import of the NIM-translation proxy
from a former `eidos-agi/free-claude-code-fork` repo (itself a fork of
`Alishahryar1/free-claude-code`). Consolidated into this repo on 2026-04-24.

**If you're cwd'd inside `proxy/`:**
- The repo's authoritative CLAUDE.md is at `../CLAUDE.md` (one level up)
- The `CLAUDE.md` and `AGENTS.md` files in this directory are from upstream
  and describe the proxy's own development conventions. They're still useful
  when working on proxy internals but they do NOT describe the wider setup.
- Our local middleware lives at `api/app.py` (search for `UsageLoggerASGI`)

**To pull upstream proxy changes:**
```bash
cd ~/repos/free-claude-code-setup
git subtree pull --prefix=proxy \
  https://github.com/Alishahryar1/free-claude-code.git main --squash
```

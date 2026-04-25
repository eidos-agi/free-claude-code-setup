> **Note:** moved into this repo from a standalone `claude-insights` repo on
> 2026-04-24. Lost git history is intentional — content was a thin wrapper around
> this project's setup work and didn't justify a separate repo until cross-project
> insights accumulate. See git log of `free-claude-code-setup` for new history.

---

# claude-insights

Personal knowledge base of non-obvious dev-tooling lessons, primarily around Claude Code, WSL, and related infrastructure on this machine.

**Purpose.** Capture insights that are durable (still true weeks/months from now) but not captured anywhere Claude would find them by default:
- Fresh regressions in tools (e.g. version-specific breakage)
- Auth-precedence pitfalls and config gotchas
- Environment-specific constraints (e.g. this being a Shadow PC with no nested virt)
- Workarounds that took time to discover and would be painful to rediscover

**Scope.** Reusable across projects and sessions — *not* project-specific. For project-specific notes, those live in the project's own repo (e.g. `/root/repos/free-claude-code-setup/PLAN.md`).

**Anti-scope.** General programming knowledge (that's in Claude's training). Architecture decisions for specific apps (those go in that app's repo). Tutorials (link externally instead).

## Structure

```
claude-insights/
├── README.md           (this file)
├── CLAUDE.md           (briefing for Claude sessions cwd'd here)
├── claude-code/        (Claude Code CLI specifics: install, auth, runtime)
├── wsl/                (WSL1/2 quirks, DNS, systemd, FS)
└── nvidia-nim/         (NIM proxy / free-tier stuff)
```

## Entry format

Each insight is a single markdown file. Terse. Structured as:

```
# <short title>

**Symptom:** what you'd see / google for
**Context:** which tool, version, platform
**Cause:** why it happens (one sentence if possible)
**Fix:** exact commands or config
**Sources:** GitHub issues, docs, PRs
**Learned:** YYYY-MM-DD, one line of session context
```

Under ~150 lines. If something's longer, it belongs in a project repo, not here.

## Adding insights

From any Claude Code session where you learn something durable:
1. Propose the entry to the user
2. On agreement, write `<category>/<slug>.md` in this repo
3. Link from README.md's index below
4. Commit with a one-line summary

## Index

### claude-code/
- [WSL1 needs Claude Code pinned to 2.1.81](claude-code/wsl1-pin-2.1.81.md) — 2.1.83+ is a Bun native binary that WSL1 can't exec
- [ANTHROPIC_API_KEY silently overrides ANTHROPIC_AUTH_TOKEN even when empty](claude-code/anthropic-api-key-precedence.md) — must explicitly set to empty string
- [Cached OAuth at ~/.claude/.credentials.json bypasses ANTHROPIC_BASE_URL](claude-code/userprofile-oauth-isolation.md) — isolate USERPROFILE/HOME for proxy routing

### wsl/
- [Shadow PC cannot run WSL2](wsl/shadow-pc-wsl1-only.md) — no nested virt from Blade's hypervisor
- [Tailscale breaks WSL DNS](wsl/tailscale-dns-fix.md) — `fec0::` placeholders inherited, pin resolv.conf
- [systemd is broken on WSL1 and must be held](wsl/systemd-hold.md) — `apt upgrade` reconfigures systemd, fails

### nvidia-nim/
- [NVIDIA NIM free-tier Claude Code routing](nvidia-nim/free-claude-code-proxy.md) — 40 req/min via Alishahryar1/free-claude-code proxy

## Related

- Project-specific setup that uses several of these: `/root/repos/free-claude-code-setup/` (PLAN.md there is the ops manual)

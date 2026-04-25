# CLAUDE.md — instructions for future Claude Code sessions in this repo

This file auto-loads when a Claude Code session has this repo as cwd. Read it first before acting.

**If you're debugging something WSL-specific, jump straight to [`insights/wsl/README.md`](insights/wsl/README.md) — symptom-keyed index covering every WSL1 failure mode we've hit (line-ending drift, exec-bit clobbering, systemd reconfigure cascade, tmp ownership traps, `ss` blindness across shells, Shadow-PC no-virt, Tailscale DNS, claude-code 2.1.83+ ELF mismatch, etc.).**

## Two self-improvement loops are wired into this repo

This repo is set up to **improve itself over time** via [hone](https://github.com/eidos-agi/hone), an MCP server that runs a 4-phase ceremony — Observe → Diagnose+Change → Measure → Retain. `.mcp.json` registers hone for any session with this repo as cwd; `.hone/mission.md` defines what "better" means here so Diagnose+Change has intent.

There are two distinct loops you can run, and they are both legitimate ongoing work:

### Loop 1 — Improve the mission

```bash
/loop 15m hone                # tick the setup repo every 15 minutes
hone 5                        # run 5 ticks back-to-back interactively
```

Each tick observes the real state of this target (STATUS.md, OPEN-QUESTIONS.md, recent usage from `~/.cache/nim-proxy-usage.jsonl`, recent commits, last validation run), diagnoses the most actionable gap, makes a proportional change, re-measures, and retains the turn into `.hone/notebook.md`. Over many ticks the notebook IS the trajectory of this mission's improvement.

The ranked definition of "better" lives in [`.hone/mission.md`](.hone/mission.md). Read that file before tick 1 — diagnoses without it tend to be vague.

### Loop 2 — Improve the instructions themselves (this file)

This `CLAUDE.md` is **in scope for hone to update**. If a tick observes that:

- A guidance section here is stale (e.g. references a path that moved, or a tool that's been renamed)
- A pattern of confusion is recurring across sessions (cross-reference `insights/` and `OPEN-QUESTIONS.md`)
- A non-obvious gotcha exists in the repo that this file doesn't surface
- A section is too long, too vague, or out-of-priority-order for the most common questions

…then the Diagnose+Change phase should propose a concrete edit to this file. Treat the instructions as code: terser is better, examples are better than prose, and *anything that bit a session is fair game to encode here*.

**The recursive closure:** if hone observes that its own meta-instructions in *this* file are themselves the bottleneck (e.g. unclear what a tick should do, or which loop to run when), Diagnose+Change can edit *these very paragraphs*. That's the `hone hone` move applied to the instructions level.

### When to run which loop

- **Active development on the mission** — Loop 1 (`hone` against this repo as the default target). Notebook fills up with concrete deltas.
- **Suspecting the instructions are off** — Loop 2: explicitly ask hone to observe and improve `CLAUDE.md`. One tick, focused.
- **Idle background time** — `/loop 30m hone` keeps Loop 1 ticking. Cheap, low-noise.

### Out of scope for hone

Don't let hone:
- Push commits to public-facing repos without explicit user approval (eidos-agi org repos especially)
- Add new dependencies to `bootstrap.sh` without hitting an OPEN-QUESTIONS entry that justifies them
- Generalize this setup to non-WSL1 environments speculatively (covered explicitly in `.hone/mission.md` "What 'better' does NOT mean")

If a hone tick proposes any of those, the Measure phase should revert.

---

**Side note:** `insights/` contains durable cross-session lessons (WSL1 quirks, auth pitfalls, claude-code version pinning). Has its own `CLAUDE.md` curator briefing — when cwd'd into `insights/`, act as a knowledge-base curator (search before regenerate, propose new entries, keep entries terse). See `insights/CLAUDE.md` for the full briefing.

## What this repo is

Local setup that lets **Claude Code** run against **NVIDIA NIM's free tier** (40 req/min, open-weight models like GLM 4.7 / Kimi K2 / Step 3.5) via a translating proxy. The user invokes everything through a `claude-nim` command.

## Where to look (in priority order)

1. **`PLAN.md`** — full operations manual. Architecture, file layout, cold-start rebuild, machine quirks, troubleshooting. If you're uncertain about anything, read it before guessing.
2. **`README.md`** — one-page quick start.
3. **`logs/`** — session notes. `2026-04-23-open-issues.md` records which bypass attacks on auth we saw and how we fixed them — check this before debugging a "proxy not routing" symptom.
4. **`scripts/setup/`** — historical bring-up scripts (not re-runnable, kept as archaeology).
5. **`scripts/setup/session-2026-04-23/`** — the scratch scripts from the original setup session. Useful as a template when rebuilding.

## Non-derivable context you need

- **Host is a Shadow PC** (Blade cloud desktop, AMD EPYC). **No nested virtualization.** WSL2 / Docker Desktop / Hyper-V guests **cannot run here**. Only WSL1. Don't suggest WSL2-only tooling.
- **Tailscale is active** on the Windows host. WSL's `/etc/resolv.conf` is pinned (`chattr +i`) because WSL's auto-generator otherwise writes broken `fec0::` DNS inherited from Windows.
- **Python 3.14 managed by uv**, not apt. The proxy's `pyproject.toml` requires 3.14. Don't `apt install python3.14` — use `uv python install 3.14`.
- **systemd is held** (`apt-mark hold systemd packagekit libnss-systemd`). WSL1 can't run systemd. Don't unhold or `apt upgrade -y` without the hold re-applied.
- **Linux Claude Code DOES run on WSL1 — but only at version 2.1.81 or older.** The 2.1.83+ releases ship as Bun-compiled native ELF binaries whose segment alignment WSL1's loader rejects with "Exec format error" ([anthropics/claude-code#38788](https://github.com/anthropics/claude-code/issues/38788), [#39385](https://github.com/anthropics/claude-code/issues/39385)). 2.1.81 is still a plain Node script (shebang `#!/usr/bin/env node`) and runs fine. Install pinned:
  ```
  npm install -g @anthropic-ai/claude-code@2.1.81
  ```
  The bash launcher prefers this Linux install when present, and falls back to Windows `claude.cmd` via interop otherwise. **Do NOT `npm update` claude-code on WSL1** — it will break. If a newer version ships a fix, verify before upgrading.

## The three auth pitfalls (this is where hours get lost)

Claude Code's auth-precedence rules silently route around `ANTHROPIC_BASE_URL` unless three things are ALL neutralized:

1. **Cached OAuth** at `%USERPROFILE%\.claude\.credentials.json` (claude.ai Max login tokens). **Fix:** launchers set `USERPROFILE=%LOCALAPPDATA%\claude-nim-profile` to an isolated empty profile.
2. **Cached account metadata** at `%USERPROFILE%\.claude.json`. Same fix above handles this — it lives under USERPROFILE too.
3. **`ANTHROPIC_API_KEY` precedence** — even when empty/unset in the current process, some path in Claude Code prefers it over `ANTHROPIC_AUTH_TOKEN`. **Fix:** launchers explicitly set `ANTHROPIC_API_KEY=` (empty). Without this, claude probes the proxy once (GET / → 401), gives up, and uses cached creds.

If you see the banner showing "`<email>'s Organization`" or the model response nailing Claude-4.6-specific knowledge cutoffs effortlessly: **the proxy is being bypassed**. Run `check-nim` to verify.

## Bootstrap + regression validation

**Fresh machine install:** `bash bootstrap.sh` from this repo. Pre-provide `NIM_API_KEY=nvapi-...` to skip the interactive prompt. Runs ~60s on a machine that already has systemd held + baseline packages; ~3 min if it has to apt-install.

**Regression tests:** `new-bin/validations/run-all.sh` — sequences 5 always-on validations, bails on first fail:
- `01-tool-use.sh` — claude-nim can drive Read/Edit/Bash through the proxy
- `02-no-leak.sh` — 4 misuse scenarios (polluted env, cached OAuth, cold proxy) all land at proxy, zero Anthropic TCP hits
- `03-rate-limit.sh` — 60-request burst: ≥40 succeed, proxy survives, 429s clean
- `04-recovery.sh` — mid-session SIGKILL + full proxy purge both self-heal on next invocation
- `05-reproducibility.sh` — runs bootstrap.sh on a scratch user, confirms end-to-end works (needs sudo; pass `--include-v5` to run-all.sh)

Run after any config change to confirm the "always-on" invariants still hold.

## How to operate

**Daily use:**
- `claude-nim [args]` — start proxy if needed, launch Claude Code routed through it
- `stop-nim-proxy` — `wsl --shutdown` which cleanly kills the proxy
- Both on PATH in WSL (`/usr/local/bin/`) and Windows (`C:\Users\Shadow\bin\`).

**Diagnostics:**
- `check-nim` — multi-step health check. Runs the verification suite from PLAN.md § Verification. Use this before and after any config change.
- `tail -f ~/.cache/nim-proxy.log` — live proxy traffic (moved from `/tmp/` to `$HOME/.cache/` in the user-scope migration — `/tmp/` was root-owned)
- Direct curl health probe: `curl -sS -o /dev/null -w "%{http_code}\n" http://localhost:8082/` → 401 means up

**Changing models:**
- Edit `~/repos/free-claude-code-setup/proxy/.env` (NOT this repo's env.template — that's the template; the live `.env` lives in the upstream proxy repo)
- Restart proxy: `stop-nim-proxy && claude-nim ...`
- Available models: `~/repos/free-claude-code-setup/proxy/nvidia_nim_models.json`

**NIM API key:**
- Stored in `~/repos/free-claude-code-setup/proxy/.env` as `NVIDIA_NIM_API_KEY=nvapi-...`
- Gitignored. Key is 68-char `nvapi-` prefix. Regenerate at build.nvidia.com/settings/api-keys if revoked.

## What NOT to do

- **Don't** delete `C:\Users\Shadow\.claude\.credentials.json` or `~/.claude.json` on the real user. The user uses paid Claude Max in other shells and needs these. Only the isolated profile (`%LOCALAPPDATA%\claude-nim-profile\`) should be bare.
- **Don't** edit `C:\Users\Shadow\bin\*.bat` — they're thin stubs that forward to the canonical copies in WSL. Edit `bin/*.bat` in this repo instead, commit.
- **Don't** try WSL2 features. They silently fail on Shadow PC.
- **Don't** run `apt upgrade` without checking `apt-mark showhold`. systemd being upgraded-then-failing cascades into broken dependency graphs.
- **Don't** set `ANTHROPIC_API_KEY` or `ANTHROPIC_BASE_URL` system-wide as User/Machine env vars. The launcher scopes them per-session on purpose so the paid Claude Code still works in normal shells.

## If the user reports it's broken

1. `check-nim` — shows which layer failed.
2. If check-nim says "proxy down": `stop-nim-proxy && claude-nim --version` (the `--version` triggers auto-restart through the launcher).
3. If check-nim says "traffic not routing": re-check `logs/2026-04-23-open-issues.md`. One of the three auth pitfalls has returned.
4. If `uv sync` starts demanding new Python versions: pyproject.toml upstream bumped. `uv python install <version>` then re-sync.
5. If the proxy starts but immediately 500s: `tail /tmp/nim-proxy.log`. Often a stale API key (regenerate) or an unreachable model ID (check nvidia_nim_models.json).

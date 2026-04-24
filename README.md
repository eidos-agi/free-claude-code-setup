# free-claude-code-setup

Machine-local setup that lets Claude Code run against NVIDIA NIM's free tier (40 req/min, ~0 cost) via a reverse proxy inside WSL.

**Canonical location:** `~/repos/free-claude-code-setup/` inside WSL Ubuntu.
(Windows accesses via `\\wsl.localhost\Ubuntu\home\dshanklin\repos\free-claude-code-setup\`.)

---

## Start here

**What this is:** a launcher (`claude-nim`) that routes Claude Code through a local proxy to NVIDIA NIM's free-tier open-weight models instead of Anthropic. You get Claude Code's UX at $0/month, at the cost of some model quality.

**The three commands that matter:**
```bash
bash bootstrap.sh                         # one-time install on a fresh user/WSL
./new-bin/validations/run-all.sh          # prove the setup still works (~4 min)
claude-nim [args]                         # daily use — same as 'claude' but routed
```

**The one gotcha that bites:** on WSL1, only `@anthropic-ai/claude-code@2.1.81` runs. 2.1.83+ ships as a Bun-compiled ELF whose segment alignment WSL1 rejects (`Exec format error`). `bootstrap.sh` pins it. Don't `npm update`.

**Current status:** see `STATUS.md`. Open questions tracked in `OPEN-QUESTIONS.md`. Why-we-did-it decisions in `ADR/`.

---

## Data flow

```
claude-code CLI  ─►  bin/claude-nim   ─►  localhost:8082  ─►  integrate.api.nvidia.com
                     • clear ANTHROPIC_API_KEY    (FastAPI proxy)    (NVIDIA NIM)
                     • isolate HOME                • translates                │
                     • set BASE_URL → proxy          Anthropic⇄OpenAI          ▼
                     • launch claude 2.1.81        • logs /v1/messages    open-weight
                                                     to ~/.cache/          models:
                                                     nim-proxy-usage       glm4.7 (Opus)
                                                     .jsonl                kimi-k2-thinking
                                                                           step-3.5-flash
```

The launcher is the **enforcement point** — if you use it, the three auth pitfalls (cached OAuth, cached account metadata, `ANTHROPIC_API_KEY` precedence) cannot leak to Anthropic. Bare `claude` bypasses all of this.

---

## Quick start

From any terminal, any directory:

```
claude-nim [any claude-code args]
```

- Starts the NIM proxy if it isn't running
- Routes `claude` through it
- Uses open-source models (GLM 4.7 / Kimi K2-thinking / Step-3.5-flash) via NVIDIA's hosted NIM endpoint

Stop everything:

```
stop-nim-proxy
```

---

## What's where

```
~/repos/free-claude-code-setup/
├── PLAN.md                Full write-up: architecture, WSL1 decision, Tailscale DNS fix, etc.
├── README.md              This file.
├── env.template           Template for the proxy's .env (key blank — fill in per-machine).
├── bin/
│   ├── claude-nim         Bash launcher (WSL).
│   ├── stop-nim-proxy     Bash stopper (WSL).
│   ├── claude-nim.bat     cmd.exe launcher (Windows).
│   └── stop-nim-proxy.bat cmd.exe stopper (Windows).
└── scripts/setup/         Historical bring-up scripts (phase2.sh, etc.).

~/repos/free-claude-code/   ← the actual proxy (upstream, git-cloned)
```

The proxy's `.env` lives in `~/repos/free-claude-code/.env` and is **gitignored** (contains the NIM key). Re-derive from `env.template` on a new machine.

---

## Changing models

Edit `~/repos/free-claude-code/.env`, change any of:

```
MODEL_OPUS="nvidia_nim/z-ai/glm4.7"
MODEL_SONNET="nvidia_nim/moonshotai/kimi-k2-thinking"
MODEL_HAIKU="nvidia_nim/stepfun-ai/step-3.5-flash"
```

Full list: `~/repos/free-claude-code/nvidia_nim_models.json`. Restart proxy: `stop-nim-proxy && claude-nim ...`.

---

## Coexistence with paid Claude

The launchers set `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` only for the cmd/bash session that invokes them. Any shell that doesn't go through the launcher talks to real Anthropic with your normal auth — untouched.

---

## Rate limit

**40 req/min, enforced by NVIDIA.** Fine for interactive coding; heavy agentic loops (parallel subagents, `/ultrareview`, etc.) will hit 429s and stall with backoff retries. Not configurable.

---

## On this machine specifically

- Host is a Shadow PC (Blade cloud desktop) — no nested virt, so WSL1 only.
- Tailscale inherited-DNS quirk — fixed via static `/etc/resolv.conf` in WSL (`chattr +i` to pin).
- Full write-up in `PLAN.md`.

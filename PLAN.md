# Free Claude Code via NVIDIA NIM — Operations Manual

**Purpose.** Make Claude Code usable against NVIDIA NIM's free tier (40 req/min) by running a local translating proxy. The result is a `claude-nim` command that looks and behaves like `claude`, but routes to open-weight models hosted by NVIDIA instead of real Claude.

**Status.** Operational. Last verified end-to-end: 2026-04-23.

**Canonical location.** `~/repos/free-claude-code-setup/` inside WSL Ubuntu (this file). Git-tracked. Windows accesses via `\\wsl$\Ubuntu\root\repos\free-claude-code-setup\`.

---

## Quick reference

| Task | Command | Runs from |
|---|---|---|
| Launch Claude Code via NIM | `claude-nim [args]` | WSL or Windows shell, any dir |
| Stop the proxy | `stop-nim-proxy` | WSL or Windows shell |
| Edit model routing | `nano ~/repos/free-claude-code/.env` | WSL |
| Inspect proxy log | `tail -f /tmp/nim-proxy.log` | WSL |
| Verify proxy is up | `curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8082/` — expect `401` | either |
| View operations history | `git log --oneline` | WSL, in this repo |

---

## Architecture

```
[Any shell, Windows or WSL]
      │
      ▼
claude-nim  (launcher — bash in WSL, .bat on Windows)
      │
      ├─ ensures proxy is running on localhost:8082
      │   (curl probe; starts it with nohup + uv if not)
      │
      └─ exec claude.exe  (Windows-native Claude Code v2.1.x, npm-installed)
               │
               ▼
         ANTHROPIC_BASE_URL=http://localhost:8082
         ANTHROPIC_AUTH_TOKEN=freecc
               │
               ▼
         WSL localhost:8082 — uvicorn + FastAPI
         ~/repos/free-claude-code/ (upstream proxy, git-cloned)
               │
               ├─ translates Anthropic API format → NIM
               ├─ enforces 40/60s rate limit client-side
               └─ maps Opus/Sonnet/Haiku → GLM/Kimi/Step
               │
               ▼
         https://integrate.api.nvidia.com/v1 (NIM hosted inference)
```

### Why WSL1 and not WSL2

This host is a **Shadow PC** (Blade/OVH cloud gaming desktop, AMD EPYC 7543P). Nested virtualization is not exposed to the guest (`SecondLevelAddressTranslationExtensions: False`), so Hyper-V / WSL2 / Docker Desktop / any other `-v` hardware-accel path flat out cannot run. WSL1 uses syscall translation — no hypervisor, no SLAT needed — and it's sufficient here because the proxy is pure Python + FastAPI + stdlib networking.

### Linux Claude Code on WSL1 — works if you pin 2.1.81

**Status:** Linux-native Claude Code runs fine on WSL1 at `@anthropic-ai/claude-code@2.1.81`. It's a plain Node script. 2.1.83+ is a Bun-compiled native binary whose ELF segment alignment WSL1's syscall shim rejects with "Exec format error" (known regression: [anthropics/claude-code#38788](https://github.com/anthropics/claude-code/issues/38788), [#39385](https://github.com/anthropics/claude-code/issues/39385), [#40546](https://github.com/anthropics/claude-code/issues/40546)).

**Install pinned:**
```
npm install -g @anthropic-ai/claude-code@2.1.81
```

**Launcher preference:** `bin/claude-nim` prefers Linux claude over Windows interop when both are installed. Linux path avoids the Windows/WSL boundary entirely — faster startup, cleaner env inheritance, native file paths (no `/mnt/c/...` translation). Windows interop remains as fallback for machines where the Linux install isn't possible.

**Don't `npm update` claude-code on WSL1.** It will pull a post-2.1.81 release and silently regress to exec-format-error. If upstream ships a WSL1-compatible fix in a newer version, verify before bumping.

---

## File layout

```
~/repos/free-claude-code-setup/     ← this repo (git-tracked)
├── PLAN.md                             ← this file
├── README.md                           ← one-page quick start
├── env.template                        ← template for the proxy's .env
├── .gitignore                          ← excludes .env, *.log, *.err
├── bin/
│   ├── claude-nim                      ← bash launcher (WSL)
│   ├── stop-nim-proxy                  ← bash stopper (WSL)
│   ├── claude-nim.bat                  ← cmd launcher (Windows)
│   └── stop-nim-proxy.bat              ← cmd stopper (Windows)
└── scripts/setup/
    ├── phase2.sh, phase2b.sh           ← historical bring-up scripts
    ├── move-to-wsl.sh                  ← one-shot: copied setup folder into WSL
    └── install-logs/                   ← DISM/BCD/WSL logs from first-time install

~/repos/free-claude-code/           ← upstream proxy code (separate git repo)
├── server.py                           ← entry point (uvicorn app)
├── pyproject.toml                      ← declares Python >=3.14; uv manages it
├── uv.lock                             ← locked deps
├── .env                                ← GITIGNORED; contains NIM API key
├── nvidia_nim_models.json              ← catalog of available NIM models
└── ...

/usr/local/bin/claude-nim               ← symlink → repo bin/claude-nim
/usr/local/bin/stop-nim-proxy           ← symlink → repo bin/stop-nim-proxy

C:\Users\Shadow\bin\claude-nim.bat      ← thin wrapper — calls \\wsl$\...\bin\claude-nim.bat
C:\Users\Shadow\bin\stop-nim-proxy.bat  ← thin wrapper
                                        (C:\Users\Shadow\bin is on User PATH)
```

**Don't** edit the wrappers in `C:\Users\Shadow\bin\` — they're one-line stubs that forward to the canonical copies in WSL. Edit canonical files in `~/repos/free-claude-code-setup/bin/`, commit, done.

---

## Verification / health checks

There are three distinct "is it working" questions, each with its own check. Run them in this order when anything feels off.

### 1. Is the proxy running? (fastest, no API usage)

```
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8082/
```

- `401` → proxy is up (it's rejecting an anonymous request, which is correct)
- `000` → nothing listening. Run `claude-nim --version` to start it, or check `tail /tmp/nim-proxy.log`
- Anything else → proxy is up but misbehaving; see Troubleshooting

Equivalent from inside the launcher: `bin/claude-nim`'s `listening()` function uses this same probe.

### 2. Is the cold-start path healthy? (what `claude-nim --version` actually proves)

Running `claude-nim --version` from a **brand-new** shell — one opened after PATH was last modified — exercises the full wiring without spending an API request:

| Stage | What it proves |
|---|---|
| Shell resolves `claude-nim` | New User PATH picked up correctly (Windows) or `/usr/local/bin` on PATH (WSL) |
| Launcher's `listening()` check runs | curl is available, port 8082 accessible from this shell |
| If proxy was down, launcher starts it | `uv run uvicorn` works, `.env` loads cleanly, Python 3.14 still installed |
| `claude.exe` is found and executes | Windows Claude Code install is intact; `claude.cmd` path correct |
| `--version` prints "2.1.x (Claude Code)" | env-var overrides didn't break anything pre-model-call |

If `claude-nim --version` prints a version line, **everything except the actual model call has been verified**. That's typically what you want — it doesn't burn a request.

**Why from a _new_ shell?** Windows stores User PATH in the registry. Live shells cached their PATH at start. Adding `C:\Users\Shadow\bin` to PATH only takes effect for processes spawned *after* the change. The setup session did that change, but any already-open shell still has the old PATH and won't find `claude-nim`. A fresh shell is the honest test.

### 3. Does end-to-end inference work? (spends 1 request against the 40/min cap)

```
claude-nim -p "say PONG and nothing else" --model claude-haiku-4-20250514
```

- Expected: `PONG` somewhere in the output
- Uses Haiku-tier (mapped to `stepfun-ai/step-3.5-flash`) — fastest and cheapest signal
- If this returns a coherent response: **proxy → NIM → model → client → stdout round-trip is healthy**

Failure modes:
- `Missing API key` in response → `.env` auth token doesn't match what the launcher sends (`freecc`)
- 502 / timeout → NIM API is down, or `NVIDIA_NIM_API_KEY` expired/revoked — regenerate at build.nvidia.com
- Garbled/hallucinated output → model got the prompt but misbehaved; try `--model claude-opus-4-20250514` (routes to glm4.7)
- `429` or retry loop → you hit the 40/min rate limit

### Periodic checks (if you want to be proactive)

None strictly required — the system is essentially stateless once set up. But if you like dashboards:

- **Rate usage:** NVIDIA doesn't expose per-key usage counters on the free tier. Proxy log (`tail -f /tmp/nim-proxy.log`) shows each request; eyeball it if you're curious.
- **Model availability:** NIM occasionally deprecates models. If `MODEL_OPUS` etc. start 404ing, check `~/repos/free-claude-code/nvidia_nim_models.json` against the current catalog at build.nvidia.com.
- **Proxy uptime:** `wsl --shutdown` or a Windows reboot will kill it; launcher auto-restarts on next `claude-nim` invocation.

---

## Key configuration

### Proxy `.env` (`~/repos/free-claude-code/.env`, perms 600, gitignored)

```
NVIDIA_NIM_API_KEY="nvapi-..."          # required, from build.nvidia.com
MODEL_OPUS="nvidia_nim/z-ai/glm4.7"
MODEL_SONNET="nvidia_nim/moonshotai/kimi-k2-thinking"
MODEL_HAIKU="nvidia_nim/stepfun-ai/step-3.5-flash"
MODEL="nvidia_nim/z-ai/glm4.7"          # fallback for unmapped requests
ENABLE_THINKING=true
ANTHROPIC_AUTH_TOKEN="freecc"           # what clients send as their fake Anthropic auth
PROVIDER_RATE_LIMIT=40
PROVIDER_RATE_WINDOW=60
PROVIDER_MAX_CONCURRENCY=5
```

See `env.template` in this repo for the full defaulted template.

### Swapping models

Catalog: `~/repos/free-claude-code/nvidia_nim_models.json`. Notable:

| Tier | Candidate IDs | Notes |
|---|---|---|
| Heavy / Opus | `z-ai/glm4.7`, `z-ai/glm5`, `moonshotai/kimi-k2.5` | Kimi K2.5 is strongest for agent tool use per NIM benchmarks |
| Balanced / Sonnet | `moonshotai/kimi-k2-thinking`, `z-ai/glm-5.1` | "-thinking" variants expose reasoning traces |
| Fast / Haiku | `stepfun-ai/step-3.5-flash`, `minimaxai/minimax-m2.7` | Pick for quick turn-around; tool reliability weaker |
| Coding-specialized | `qwen/qwen3-coder-480b-a35b-instruct` | Large MoE; slower but code-tuned |

After editing `.env`: `stop-nim-proxy && claude-nim ...` (next invocation starts fresh).

### Rate limit behaviour

40 req/min is a hard ceiling from NVIDIA. The proxy mirrors it client-side (`PROVIDER_RATE_LIMIT`/`PROVIDER_RATE_WINDOW`). Each tool call from Claude Code counts as one request. Heavy agent loops (`/ultrareview`, parallel subagents) will hit 429s. Client retries with exponential backoff, no data loss, just latency.

---

## Machine-specific quirks (this host)

Facts about this physical/virtual machine that aren't derivable from reading any code:

1. **Shadow PC (Blade cloud desktop).** `Manufacturer: Blade`, `Model: Shadow Computer`. AMD EPYC 7543P visible to guest, but no SLAT passthrough. Consequence: no WSL2, no Hyper-V, no Docker-for-Windows. Only WSL1 works.

2. **Tailscale is active on the host.** WSL by default inherits Windows DNS config, which points at Tailscale's MagicDNS placeholders (`fec0:0:0:ffff::1-3`, non-routable from inside WSL). Fix, already applied:
    - `/etc/wsl.conf`:
      ```
      [network]
      generateResolvConf = false
      ```
    - `/etc/resolv.conf` manually written with `1.1.1.1 / 1.0.0.1 / 8.8.8.8`, then `chattr +i` so WSL respawn can't clobber it.

3. **systemd is broken** in WSL1 (expected — no cgroup namespaces). The systemd package is held via `apt-mark hold systemd packagekit libnss-systemd` so `apt upgrade` doesn't keep failing on reconfigure. No consequence for the proxy (doesn't need systemd).

4. **Windows PATH leaks into WSL.** Every WSL login inherits `/mnt/c/...` paths, including `/mnt/c/Program Files/nodejs`. That Windows node.exe prints "WSL 1 is not supported" when accidentally invoked from bash and has confused shell scripts during setup. Harmless but noisy. Linux-side nvm + node 20 exists at `~/.nvm/versions/node/v20.20.2/` in case it's ever needed (it isn't for this project).

5. **Python 3.14 is uv-managed, not system.** Ubuntu 24.04 ships Python 3.12. The proxy's `pyproject.toml` requires `>=3.14`, so `uv python install 3.14` was run once. `uv sync` picks it up automatically. **Do not replace with `sudo apt install python3.14` or the deadsnakes PPA** — uv's managed install is what's locked in uv.lock's venv.

6. **Root user, no normal user.** Ubuntu was installed with `--no-launch` to skip the interactive first-run user creation. Everything runs as root. If you want a normal user later: `adduser shadow && usermod -aG sudo shadow && ubuntu config --default-user shadow`.

---

## Cold-start rebuild

If this PC gets wiped or you're doing the same thing on another Shadow-class machine. Expected time: ~30 min, one reboot.

1. **Enable Windows features** (admin PowerShell):
   ```
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   ```
   **Reboot.** (VMP activation requires it.)

2. **Install Ubuntu as WSL1** (Shadow has no nested virt, WSL2 will fail):
   ```
   wsl --set-default-version 1
   wsl --install -d Ubuntu --no-launch --web-download
   ```

3. **Fix DNS** (Tailscale quirk) — from Windows shell:
   ```
   wsl -d Ubuntu -u root -- bash -c "cat > /etc/wsl.conf <<EOF
   [network]
   generateResolvConf = false
   EOF
   rm -f /etc/resolv.conf
   printf 'nameserver 1.1.1.1\\nnameserver 1.0.0.1\\nnameserver 8.8.8.8\\n' > /etc/resolv.conf
   chattr +i /etc/resolv.conf"
   wsl --shutdown
   ```

4. **Base toolchain** (inside WSL as root):
   ```
   apt-get update && apt-get install -y python3 python3-pip python3-venv git curl build-essential
   apt-mark hold systemd packagekit libnss-systemd  # stop noisy upgrade failures
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```

5. **Clone the proxy and setup repo:**
   ```
   mkdir -p /root/repos && cd /root/repos
   git clone https://github.com/Alishahryar1/free-claude-code.git
   # Clone this setup repo (replace with your fork/mirror if hosted):
   git clone <this-repo-url> free-claude-code-setup
   ```

6. **Configure `.env`:**
   ```
   cd ~/repos/free-claude-code
   cp ~/repos/free-claude-code-setup/env.template .env
   chmod 600 .env
   # Edit .env: paste NVIDIA_NIM_API_KEY (get it at build.nvidia.com/settings/api-keys)
   ```

7. **Install Python + deps:**
   ```
   ~/.local/bin/uv python install 3.14
   cd ~/repos/free-claude-code && ~/.local/bin/uv sync
   ```

8. **Wire launchers to PATH:**
   ```
   ln -sf ~/repos/free-claude-code-setup/bin/claude-nim     /usr/local/bin/claude-nim
   ln -sf ~/repos/free-claude-code-setup/bin/stop-nim-proxy /usr/local/bin/stop-nim-proxy
   ```
   From Windows PowerShell (non-admin):
   ```
   mkdir C:\Users\<you>\bin -Force
   # Copy the two .bat stubs from \\wsl$\Ubuntu\root\repos\free-claude-code-setup\bin\
   # Add to User PATH:
   $p = [Environment]::GetEnvironmentVariable('Path','User')
   if (($p -split ';') -notcontains "C:\Users\<you>\bin") {
     [Environment]::SetEnvironmentVariable('Path',"$p;C:\Users\<you>\bin",'User')
   }
   ```

9. **Smoke test:**
   ```
   curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8082/     # expect: 000 (proxy not running yet)
   claude-nim --version                                                # starts proxy, runs claude
   curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8082/     # expect: 401 (proxy up)
   ```

---

## Troubleshooting

**`claude-nim` says proxy didn't come up in 20s.**
Check `tail -30 /tmp/nim-proxy.log`. Common causes:
- `.env` missing or malformed — regenerate from `env.template`
- `NVIDIA_NIM_API_KEY` empty or expired — regenerate at build.nvidia.com
- Python 3.14 missing — `~/.local/bin/uv python install 3.14`
- Deps unsynced after an upstream `free-claude-code` pull — `cd ~/repos/free-claude-code && uv sync`

**Claude Code gets 429 errors / long pauses.**
You hit the 40/min rate limit. Not fixable — it's a NIM cap. Reduce `PROVIDER_MAX_CONCURRENCY` in `.env` for smoother pacing. Fall back to real Claude for heavy agent runs.

**DNS stops working in WSL after Windows/Tailscale update.**
If Tailscale gets reinstalled or WSL is reregistered, `/etc/resolv.conf` may regen despite `chattr +i`. Redo step 3 of the cold-start.

**`claude-nim.bat` on Windows fails with "system cannot find the path".**
`\\wsl$\Ubuntu\...` works only when WSL is running. `wsl -l -v` to confirm Ubuntu exists and is Stopped/Running. If Stopped, running `claude-nim.bat` kicks it up anyway; should be fine.

**Model response quality feels off vs. real Claude.**
Expected. Open-weight models (GLM/Kimi/Qwen) are weaker on tool-calling fidelity and long-context coherence. For casual interactive work you won't notice; for agentic workflows, keep real Claude as the primary.

**`claude-nim` chat banner says "API Usage Billing · <email>'s Organization" and responses feel indistinguishable from real Claude.**
Claude Code's auth precedence prefers a stored OAuth / API-key cred at `%USERPROFILE%\.claude\.credentials.json` over `ANTHROPIC_BASE_URL`/`ANTHROPIC_AUTH_TOKEN` env vars. If you've ever run `/login` or used `claude.ai` on this Windows account, that cred is cached and will **silently route traffic to real Anthropic on your paid plan even when the proxy is running**. Our launchers now sidestep this by pointing `USERPROFILE` (Windows) / WSLENV-USERPROFILE (bash) at an isolated empty profile at `%LOCALAPPDATA%\claude-nim-profile\`, which has no stored creds so env-var auth wins.

Two tells that the bypass is happening:
- Response style is polished Anthropic-model output (no visible chain-of-thought leakage even when the proxy has `ENABLE_THINKING=true`)
- Banner shows your real Anthropic org / subscription tier
Definitive check: `curl -sS -X POST http://localhost:8082/v1/messages -H "x-api-key: freecc" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" -d '{"model":"claude-haiku-4-20250514","max_tokens":10,"messages":[{"role":"user","content":"hi"}]}'`. The SSE response's `"model"` field will show the actual backing model (e.g. `"stepfun-ai/step-3.5-flash"`). If the proxy routes correctly but Claude Code doesn't use it, the `USERPROFILE` isolation is what's missing.

**Switch to a different provider (OpenRouter, DeepSeek, LM Studio).**
Edit `.env`, set that provider's API key, change `MODEL_*` values to `open_router/...` / `deepseek/...` / `lmstudio/...`. Restart proxy. See `~/repos/free-claude-code/README.md` upstream for provider-specific prefix conventions.

---

## History / setup narrative

Original bring-up was a single session on 2026-04-23. Preserved here for reference — future-you may find one of these gotchas again on a similar host.

### What worked on the first try
- Ubuntu base install via `wsl --install`
- `uv python install 3.14` + `uv sync`
- Model mapping + `.env` configuration
- Port forwarding (WSL1 shares Windows network namespace, zero config needed)

### What blocked us (in order of discovery)
1. **`wsl --install` refused without VMP.** Fix: DISM enable VirtualMachinePlatform + reboot.
2. **Still refused after VMP was on.** Root cause: Shadow PC doesn't expose SLAT to the guest → WSL2 impossible on this host. Fix: `wsl --set-default-version 1` + re-install as WSL1.
3. **DNS didn't resolve inside WSL.** Root cause: Tailscale on the host left WSL with fec0:: placeholder DNS. Fix: disable `generateResolvConf`, hand-write `/etc/resolv.conf`, `chattr +i`.
4. **`apt upgrade` failed configuring systemd.** WSL1 can't run systemd. Fix: `apt-mark hold systemd packagekit libnss-systemd`. Harmless going forward.
5. **`npm install -g @anthropic-ai/claude-code` refused WSL1.** Decision: don't install Linux Claude Code at all; use Windows-native, which already exists.
6. **Node 24 LTS crashes on WSL1.** Only relevant if you want Linux-side node; we don't for this project. Workaround: `nvm install 20`.
7. **`ss -ltn` in WSL1 is per-session** — couldn't see the proxy started in another shell. Fix: use curl HTTP probe for the `listening()` check instead (see `bin/claude-nim`).
8. **PowerShell's `&` operator mangled `setlocal` in the .bat.** Fix: removed `setlocal EnableDelayedExpansion`, rewrote counter loop as `for /l`.

### What we explicitly didn't do and why
- **Didn't install Claude Code in WSL.** Upstream refuses WSL1; Windows-native works fine via localhost. Don't retry this on Shadow-class hosts.
- **Didn't enable Hyper-V.** No effect — SLAT still missing.
- **Didn't create a non-root Linux user.** Everything's root; fine for a local dev VM. Add one later if you want `sudo` semantics.
- **Didn't set env vars globally in Windows.** Per-shell scoping via the launcher keeps the paid Claude Code session on this machine uncontaminated.

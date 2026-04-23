# Free Claude Code via NVIDIA NIM — Setup Plan

**Created:** 2026-04-23
**Machine:** Windows 11 Home, user `Shadow`
**Goal:** Run Claude Code CLI backed by NVIDIA NIM's free tier (40 req/min) using open-source models (GLM 4.7, Kimi K2, etc.), inside WSL/Ubuntu, without disturbing the existing native-Windows Claude Code install or its auth.

---

## What this actually gets us

- Claude Code frontend, unchanged UX
- Backend swapped from Anthropic → NVIDIA NIM hosted open-source models
- Free (rate-limited to ~40 req/min, no token caps, no credit card)
- **Not real Claude** — tool-calling quality and long-context behavior will differ
- Separate shell/env — the existing paid Claude Code session stays intact

---

## Starting state (verified 2026-04-23)

| Component | Status |
|---|---|
| Claude Code (Windows-native) | 2.1.118 ✅ |
| git | 2.54 ✅ |
| node | 22.2 ✅ |
| Python (native Windows) | ❌ (MS Store alias only) |
| uv | ❌ |
| WSL runtime | installed, WSL 2 default ✅ |
| WSL distro | **none installed** |
| Ports 8000 / 8080 / 8082 | all free ✅ |

### Environment quirks (this specific machine)

- **Host is a Shadow PC** (Blade/OVH cloud gaming desktop): `Manufacturer: Blade`, `Model: Shadow Computer`, AMD EPYC 7543P. Everything below flows from this.
- **No nested virtualization** → WSL2 cannot run here (`HCS_E_HYPERV_NOT_INSTALLED` even with VMP enabled + reboot). CPU reports `SecondLevelAddressTranslationExtensions: False` because it's a guest VM without SLAT passthrough.
- **Fell back to WSL1** — syscall-translation shim, no hypervisor needed. Sufficient for our use case (Python + uv + git + node + Claude Code CLI). Known limits: no systemd, slower FS on /mnt/c, some Docker use cases broken. Not relevant to this project.
- **Tailscale is active on the host** (`.ts.net` search domain). WSL inherited placeholder IPv6 DNS (`fec0:0:0:ffff::1-3`) that doesn't resolve. Fix applied: `/etc/wsl.conf` with `[network] generateResolvConf = false` + manual `/etc/resolv.conf` with `1.1.1.1`, `1.0.0.1`, `8.8.8.8`. Marked immutable via `chattr +i` so WSL respawn doesn't stomp it.

---

## Architecture (revised — everything lives in Linux)

```
[WSL Ubuntu]
    ├── Claude Code CLI (Linux install, separate from Windows-native)
    │       env: ANTHROPIC_BASE_URL=http://localhost:8082
    │            ANTHROPIC_AUTH_TOKEN=freecc
    │       ▼
    └── free-claude-code proxy on :8082 (uvicorn, Python via uv)
            │  translates Anthropic API format → NIM format
            ▼
[Internet] build.nvidia.com/v1  (NIM hosted inference)
    │
    └── GLM 4.7 / Kimi K2 / step-3.5 etc.

[Windows] — untouched
    └── Existing Claude Code 2.1.118 (paid/real Claude) stays as-is
```

Why fully Linux:
- Python/uv/node tooling is first-class on Linux; tutorial commands copy-paste verbatim
- No Windows/WSL shell env-var gymnastics — everything in one process space
- Complete isolation: the paid Claude Code on Windows can't accidentally inherit the proxy env vars
- Reusable Linux dev environment for future projects
- WSL filesystem access to Windows drives via `/mnt/c/...` when you want to touch Windows files

---

## Phases

### Phase 1 — Install WSL + Ubuntu
- Run `wsl --install -d Ubuntu` (requires UAC elevation)
- Reboot if prompted
- Complete first-boot username/password setup for Ubuntu
- Verify: `wsl -l -v` shows Ubuntu running version 2
- **User touchpoint:** UAC prompt, possible reboot, set Ubuntu username/password

### Phase 2 — Inside Ubuntu: base toolchain
- `sudo apt update && sudo apt upgrade -y`
- `sudo apt install -y python3 python3-pip python3-venv git curl build-essential`
- Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Install Node LTS via nvm (cleaner than apt's node):
  - `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash`
  - `nvm install --lts`
- Install Claude Code in Linux: `npm install -g @anthropic-ai/claude-code`
- **Do NOT log in** to this Linux Claude Code with your real account — we're pointing it at the proxy
- Verify: `python3 --version`, `uv --version`, `git --version`, `node --version`, `claude --version`
- Create working dir: `~/repos/`

### Phase 3 — NVIDIA NIM API key
- User signs up / logs in at https://build.nvidia.com
- Generate key at `build.nvidia.com/settings/api-keys` (starts with `nvapi-`)
- **User touchpoint:** paste key when prompted — I will not save it in plaintext anywhere except the `.env` it needs to live in

### Phase 4 — Clone & configure free-claude-code
- `git clone https://github.com/Alishahryar1/free-claude-code.git ~/repos/free-claude-code`
- `cp .env.example .env`
- Populate `.env`:
  ```
  NVIDIA_NIM_API_KEY="nvapi-..."
  MODEL_OPUS="nvidia_nim/z-ai/glm4.7"
  MODEL_SONNET="nvidia_nim/moonshotai/kimi-k2-thinking"
  MODEL_HAIKU="nvidia_nim/stepfun-ai/step-3.5-flash"
  MODEL="nvidia_nim/z-ai/glm4.7"
  ENABLE_THINKING=true
  ANTHROPIC_AUTH_TOKEN="freecc"
  ```
- Inspect `server.py` / requirements before first run — confirm no surprises

### Phase 5 — Smoke test the proxy
- `uv run uvicorn server:app --host 0.0.0.0 --port 8082` inside WSL
- From Windows: `curl http://localhost:8082/` to confirm port forwarding works
- Send a minimal Anthropic-format request, confirm a NIM response comes back

### Phase 6 — Launch Claude Code against the proxy (inside WSL)
- Second WSL shell (`wsl` from any Windows terminal opens one)
- Export env in `~/.bashrc` (scoped to Linux, cannot leak to Windows Claude):
  ```bash
  export ANTHROPIC_AUTH_TOKEN="freecc"
  export ANTHROPIC_BASE_URL="http://localhost:8082"
  ```
- `source ~/.bashrc` then `claude`
- Verify model responds; test a simple tool call (file read)

### Phase 7 — Convenience launcher
- Create `~/bin/claude-nim` script inside Ubuntu:
  - Ensures proxy is running (starts it via `nohup`/`tmux` if not)
  - Launches `claude` in the current directory with env set
- Also create a Windows-side wrapper `C:\Users\Shadow\repos\free-claude-code-setup\claude-nim.bat` that just execs `wsl claude-nim` so you can launch from any Windows folder
- Test cold-start from fresh cmd prompt and from inside WSL

---

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Env vars leak into normal Claude session | Only set per-shell, never System or User env. Keep one terminal window per mode. |
| WSL install requires reboot, breaks this session | Save plan to disk first (this file). Resume from Phase 2 after reboot. |
| NIM API key accidentally committed | Folder is not a git repo; `.env` only lives inside the cloned `free-claude-code` repo which already has `.gitignore` for it. Verify before any commit. |
| Proxy process dies silently | Phase 7 launcher runs it in a visible WSL window so failures are obvious. |
| Rate-limit (40 req/min) hit during agent loops | Expected. Not a fix — a known ceiling of the free tier. |
| Model quality shock (vs. real Claude) | Expected. Evaluate after first real task; can swap models by editing `.env` and restarting proxy. |

---

## Rollback

Full teardown if we bail:
- `wsl --unregister Ubuntu` (removes distro, keeps WSL runtime)
- `rm -rf C:\Users\Shadow\repos\free-claude-code-setup`
- Delete NIM API key from build.nvidia.com

No changes to existing Claude Code install, no global env var changes, no system-level installs outside WSL.

---

## Progress log

- [x] **Phase 1** — WSL + Ubuntu installed (WSL1, not 2 — Shadow PC has no nested virt)
- [x] **Phase 2** — Python 3.14 (via uv), uv 0.11.7, git 2.43. Node skipped (not needed)
- [x] **Phase 3** — NIM API key obtained and applied
- [x] **Phase 4** — Proxy cloned to `/root/repos/free-claude-code/` inside WSL; `.env` configured, perms 600, all three Claude tiers routed to NIM models
- [x] **Phase 5** — Proxy smoke test: `POST /v1/messages` → live streaming from `moonshotai/kimi-k2-thinking` via NIM ✅
- [x] **Phase 6** — Windows Claude Code → proxy → NIM → response confirmed end-to-end (one-shot `-p` test returned the expected string)
- [x] **Phase 7** — Launcher `claude-nim.bat` works: reuses existing proxy if up, otherwise starts it in a minimized WSL window and waits for port to open; `stop-nim-proxy.bat` kills it via `wsl --shutdown`

---

## How to use it

**Start / run:**
```
C:\Users\Shadow\repos\free-claude-code-setup\claude-nim.bat
```
- Pops a minimized "NIM Proxy" window if the proxy isn't already up
- Sets `ANTHROPIC_BASE_URL` and `ANTHROPIC_AUTH_TOKEN` for *this cmd session only*
- Launches `claude` with any args you pass

**Stop:**
- Close the "NIM Proxy" taskbar window, OR
- Run `stop-nim-proxy.bat` (calls `wsl --shutdown`, kills everything in WSL)

**Edit models:** `wsl -d Ubuntu -u root nano /root/repos/free-claude-code/.env` — change `MODEL_OPUS`/`SONNET`/`HAIKU`, save, restart proxy.

**Available NIM models** (see `/root/repos/free-claude-code/nvidia_nim_models.json` for full list):
- Strong agentic: `z-ai/glm4.7`, `z-ai/glm5`, `moonshotai/kimi-k2.5`, `moonshotai/kimi-k2-thinking`
- Coding-specialized: `qwen/qwen3-coder-480b-a35b-instruct`, `deepseek-ai/deepseek-coder-6.7b-instruct`
- Fast/light: `stepfun-ai/step-3.5-flash`

**Coexistence with real Claude:** your Windows-native `claude` auth is untouched. Any terminal that DOESN'T set those two env vars still talks to real Anthropic. The proxy only applies when you launch via `claude-nim.bat`.

---

## 🔁 RESUME AFTER REBOOT

After you reboot this PC:

1. Open Claude Code (this same directory: `C:\Users\Shadow\repos\free-claude-code-setup\`).
2. Tell Claude: **"continue the NIM setup"**.
3. Claude will verify VMP is now active, run `wsl --install -d Ubuntu --no-launch`, wait for download, then walk you through Ubuntu first-run (username/password — pick any; this is a local-only Linux user).

If Claude isn't around, resume manually:
```powershell
wsl --install -d Ubuntu --no-launch
# then launch Ubuntu once from Start Menu to set username/password
wsl -l -v    # should show Ubuntu  Running  2
```

Relevant logs from Phase 1 work (safe to delete once Phase 1 is complete):
- `dism.log`         — WSL feature enable
- `vmp.log`          — VirtualMachinePlatform enable
- `vmp-status.log`   — confirms VMP state = Enabled
- `wsl-install.log`  — early attempt (may be empty)
- `wsl-install.err`  — early attempt error log

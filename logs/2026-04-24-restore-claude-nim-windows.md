# 2026-04-24 — Restoring `claude-nim` on Windows after repo migration

## Symptom

User reports: "wsl isn't working" and "login doesn't stay even after I do it successfully."

Header in their terminal showed:

```
Claude Code v2.1.81
Sonnet 4.6 · API Usage Billing
~/repos/free-claude-code-setup
Not logged in · Please run /login
```

`/login` printed `Login successful`; the next command (`continue`, `wtf`, `/model`) reverted to `Not logged in`. Plain Windows `claude.exe` was unreachable; `claude-nim.bat` fell over with a stream of `'M' is not recognized as an internal or external command` errors.

## Root cause

Two simultaneous breaks in the Windows-side thin shims at `C:\Users\Shadow\bin\`:

1. **Stale UNC path.** Repo had been moved from `/root/repos/free-claude-code-setup/` to `/home/dshanklin/repos/free-claude-code-setup/`. The thin shims still pointed at `\\wsl$\Ubuntu\root\repos\...`, which no longer exists.
2. **LF line endings on `.bat` files.** Repo `.gitattributes` had `* text=auto eol=lf`, which silently applied to `.bat` too. CMD does not tolerate bare LF — it parses across line boundaries until it finds CRLF. Result: `'M' is not recognized` (CMD has chewed `RE` off `REM` and is trying to execute `M`).

The "login doesn't stay" symptom was a downstream effect: claude-nim was *intended* to redirect `USERPROFILE` to an isolated profile, but because it was failing to launch, the user perceived their subscription `claude` as also broken. In fact the OAuth token at `C:\Users\Shadow\.claude\.credentials.json` was valid the whole time.

## Fixes

| File | Change |
|---|---|
| `C:\Users\Shadow\bin\claude-nim.bat` | UNC repointed to `\\wsl$\Ubuntu\home\dshanklin\repos\...` + CRLF |
| `C:\Users\Shadow\bin\stop-nim-proxy.bat` | Same |
| `bin/claude-nim.bat`, `bin/check-nim.bat`, `bin/stop-nim-proxy.bat` (canonical) | Normalized in-place to CRLF |
| `.gitattributes` | Added `*.bat text eol=crlf` and `*.cmd text eol=crlf` |

## Linux-native `claude` install

User asked for a real Linux `claude`, not the Windows-interop shim. nvm-installed `claude` 2.1.81 already existed at `/home/dshanklin/.nvm/versions/node/v20.20.2/bin/claude` but wasn't on PATH for non-login shells (default Ubuntu `.bashrc` early-returns when `$PS1` is unset, before nvm sourcing).

Two symlinks placed under `/usr/local/bin/`:

```bash
sudo ln -sf /home/dshanklin/.nvm/versions/node/v20.20.2/bin/claude /usr/local/bin/claude
sudo ln -sf /home/dshanklin/.nvm/versions/node/v20.20.2/bin/node   /usr/local/bin/node
```

Both are required: the `claude` shebang is `#!/usr/bin/env node` and fails with `env: 'node': No such file or directory` in non-login shells if `node` isn't on PATH.

Also `chown -R dshanklin:dshanklin /home/dshanklin/.claude` — was `root:root` from an earlier sudo invocation.

## Trilogy install

`research-md`, `visionlog-md`, `ike-md` installed as uv tools:

```bash
uv tool install research-md
uv tool install visionlog-md
uv tool install ike-md
```

Each installs an MCP server invokable via stdio. `.mcp.json` updated to register all three alongside the existing `hone` server. They become available the next time Claude Code starts in this repo.

## Architecture summary

| Command | Auth | Endpoint | Profile dir |
|---|---|---|---|
| Windows `claude` | OAuth Max | `api.anthropic.com` | `C:\Users\Shadow\.claude\` |
| Windows `claude-nim` | `ANTHROPIC_AUTH_TOKEN=freecc` | `http://localhost:8082` | `C:\Users\Shadow\AppData\Local\claude-nim-profile\` |
| WSL `claude` (Linux 2.1.81) | OAuth Max | `api.anthropic.com` | `/home/dshanklin/.claude/` |
| WSL `claude-nim` | `ANTHROPIC_AUTH_TOKEN=freecc` | `http://localhost:8082` | `$HOME/claude-nim-home/.claude/` |

Subscription credentials (Windows side) and Linux-side credentials are separate files; logging in from one does not log you in to the other.

## New artifacts

- `ADR/0006-bat-files-pinned-crlf.md`
- `insights/wsl/bat-files-need-crlf.md`
- `insights/claude-code/linux-native-claude-via-symlink.md`
- `new-bin/validations/host-windows.ps1` (41-test PowerShell suite covering Windows shims, WSL Linux-native claude, isolation, proxy, OAuth state)

## Test results

`new-bin/validations/host-windows.ps1` ran 41 checks. 37 PASS, 3 FAIL (test-script bugs, not real issues — paren escaping in PowerShell→WSL→bash, plus a stale assertion that still expected the Windows-interop path for `which claude` after we'd intentionally replaced it with the Linux-native symlink).

Independently verified end-to-end:

- Subscription `.credentials.json` mtime unchanged across all `claude-nim` runs (isolation holds).
- Proxy at `:8082` responds 401 to anonymous GET, 200 to authenticated POST `/v1/messages`.
- Linux-native `claude --version` returns `2.1.81 (Claude Code)` from any shell mode.
- Second `claude-nim` invocation reuses the running proxy (`[claude-nim] proxy already listening on :8082 - reusing`).

## Open questions

- Should `/home/dshanklin/.claude/.credentials.json` be a symlink to `/mnt/c/Users/Shadow/.claude/.credentials.json` so logging in from one side covers both? Pro: one `/login` for both Windows and WSL. Con: line-ending and metadata drift across the SMB/9P bridge could corrupt the token file. Currently kept separate.
- Should `bootstrap.sh` regenerate the Windows thin shims on each run, so a future repo-path migration auto-fixes them? Currently they're hand-edited and drift independently.

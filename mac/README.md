# mac/ — free-claude-code-setup on macOS

The macOS-native track. Everything in this folder is the Mac counterpart of the WSL1 launchers and bootstrap that live one level up.

> **Why a separate track?** The repo's main `bootstrap.sh` is shaped by WSL1
> constraints (systemd hold, `chattr +i /etc/resolv.conf`, claude-code 2.1.81
> pin to dodge the Bun-ELF segment-alignment loader bug, Windows `claude.cmd`
> fallback). On macOS none of that applies — the Mach-O claude binary runs
> fine, there's no systemd to hold, and there's no Windows side. Forking the
> launchers here keeps each track readable instead of spraying `if Darwin`
> branches through the originals.

## Quick start

From the repo root, on a Mac that has `curl`, `git`, and `claude` installed:

```bash
NIM_API_KEY=nvapi-... bash mac/bootstrap.sh
```

That script:
1. Installs `uv` if it's missing (Astral installer).
2. Provisions `proxy/.env` from `env.template` with your key, mode 600.
3. Runs `uv sync` in `proxy/` (downloads Python 3.14 + FastAPI deps).
4. Symlinks `claude-nim`, `stop-nim-proxy`, and `check-nim` into the first
   writable directory of `/opt/homebrew/bin`, `/usr/local/bin`, or
   `~/.local/bin`.
5. Smoke-tests the proxy with `claude-nim -p 'PONG'`.

After that:

```bash
claude-nim                # daily use — same as 'claude' but routed via NIM
check-nim                 # health check (add --live for one real inference)
stop-nim-proxy            # kill the proxy on :8082
```

## Layout

```
mac/
├── README.md          ← you are here
├── bootstrap.sh       ← one-shot installer
└── bin/
    ├── claude-nim     ← starts proxy if needed, runs claude with proxy env
    ├── check-nim      ← multi-step health check
    └── stop-nim-proxy ← kills the proxy via lsof (no `wsl --shutdown` here)
```

## Notes specific to macOS

- **No claude version pin.** The WSL1 ELF-loader bug doesn't apply to Mach-O
  binaries — the launcher runs whatever `claude` is on PATH (or pointed to by
  `$CLAUDE_BIN`). To prefer a specific install:
  `CLAUDE_BIN=$HOME/.local/bin/claude claude-nim`.
- **Proxy bind:** the launcher binds to `127.0.0.1` (loopback only), unlike the
  WSL launcher which uses `0.0.0.0`. macOS doesn't need cross-VM exposure.
- **HOME isolation:** `claude-nim` redirects `$HOME` to `~/claude-nim-home`
  for the child process so an OAuth login can't write into the real
  `~/.claude/.credentials.json`. Your normal Claude Code session, started
  outside this launcher, is untouched.
- **Proxy log:** `~/.cache/nim-proxy.log`.
- **Stop semantics:** `stop-nim-proxy` finds the listener via
  `lsof -ti tcp:8082 -sTCP:LISTEN`, sends SIGTERM, waits, escalates to
  SIGKILL if needed.

## What we DON'T touch from the WSL track

The Mac scripts deliberately don't:

- pin claude-code to 2.1.81
- look for `/mnt/c/Users/.../claude.cmd`
- hold systemd or pin `/etc/resolv.conf`
- assume Windows `USERPROFILE` semantics

If you're hacking on this and want the WSL behaviour, look at `bin/` (one
level up). The two trees mirror each other on purpose — drop a symlink, not a
shared file, if you want them to stay readable.

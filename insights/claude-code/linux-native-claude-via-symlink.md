# Linux-native `claude` on PATH for non-login shells: symlink node *and* claude

**Goal:** Running `claude` from any WSL shell (login, non-login, scripts, cron, IDE terminal) resolves to the Linux-native nvm-installed binary, not the Windows interop shim at `/mnt/c/Users/Shadow/AppData/Roaming/npm/claude`.

**Why this is non-obvious:**

- nvm sources its PATH manipulation from `~/.bashrc`. Default Ubuntu `.bashrc` has an early `[ -z "$PS1" ] && return` that skips everything for non-interactive shells. So `bash -c 'which claude'` doesn't see nvm — it falls through to the inherited PATH which has `/mnt/c/.../npm/` from WSL interop.
- `which claude` from a login non-interactive shell (`bash -lc`) sources `.profile` → `.bashrc` → and *still* hits the early return, depending on whether `$PS1` is set.
- Net effect: nvm-installed `claude` lives at `~/.nvm/versions/node/<v>/bin/claude` but is functionally invisible to most shell invocations.

**Fix:** put the binary at a path that's on the system PATH for all shell modes. `/usr/local/bin` is the canonical answer.

```bash
sudo ln -sf "$HOME/.nvm/versions/node/v20.20.2/bin/claude" /usr/local/bin/claude
sudo ln -sf "$HOME/.nvm/versions/node/v20.20.2/bin/node"   /usr/local/bin/node
```

**Both symlinks are required.** The `claude` script's shebang is `#!/usr/bin/env node` — without `node` on PATH for the running shell, you get:

```
$ claude --version
/usr/bin/env: 'node': No such file or directory
```

Symptom is misleading: `which claude` says `/usr/local/bin/claude`, the file exists and is executable, but invoking it errors out. The shebang resolution is what's failing, and the error mentions `env`, not `claude`.

**Optional third symlink:** `npm` if you need `npm` from non-interactive shells (e.g. CI scripts that install packages without sourcing nvm).

```bash
sudo ln -sf "$HOME/.nvm/versions/node/v20.20.2/bin/npm" /usr/local/bin/npm
```

**Don't forget:** `~/.claude/` ownership. If `claude` (or `claude-nim`) ever ran as root before this symlink existed, `~/.claude/` may be owned by `root:root`. Login from the user account will fail to write `.credentials.json`. Fix:

```bash
sudo chown -R "$USER:$USER" ~/.claude
```

**WSL1 caveat:** Pin to `@anthropic-ai/claude-code@2.1.81`. Versions 2.1.83+ use Bun ELF segment alignment that the WSL1 loader rejects with `Exec format error` — see `ADR/0002-pin-claude-code-2.1.81.md` and the upstream issue at `anthropics/claude-code#38788`.

**Verify:**

```bash
bash -c 'which claude && claude --version'   # /usr/local/bin/claude, 2.1.81 (Claude Code)
bash -lc 'which claude && claude --version'  # same — login or non-login, both work
```

**OAuth credential location after this:** Linux-native `claude` reads `~/.claude/.credentials.json` (i.e. `/home/<user>/.claude/.credentials.json` in WSL). This is *separate* from the Windows-side `C:\Users\<user>\.claude\.credentials.json`. Logging in from one doesn't log you in to the other. If you want shared OAuth state across both, symlink the credentials file — but be aware that mtime/permissions can drift across the SMB/9P boundary.

**Sources:** Hit 2026-04-24 on Shadow PC. nvm-installed `claude` 2.1.81 existed at `/home/dshanklin/.nvm/versions/node/v20.20.2/bin/claude` but `which claude` (non-login) returned the Windows interop path. After symlinking just `claude` to `/usr/local/bin/`, invocations errored on `node` resolution. After also symlinking `node`, both `bash -c` and `bash -lc` resolve correctly.

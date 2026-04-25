# `/tmp/` files left by one user become permission-denied for another

**Symptom:** A long-running service (proxy, daemon) used to log to `/tmp/<service>.log`. After you migrate the service from running as root to running as a normal user, the new invocation fails with:

```
/path/to/launcher: line 30: /tmp/<service>.log: Permission denied
```

The service's own start logic shows it briefly came up, but the launcher's redirect (`>"$LOG"`) couldn't open the existing root-owned log file for append. The launcher then bails and the user thinks the service is dead.

**Worse symptom:** the user runs `sudo rm /tmp/<service>.log` to "fix it," then on next start, the new run logs are in a fresh user-owned file — but the *old root-owned content* is gone forever. If the old logs had been useful diagnostics, they're now lost.

**Context:** WSL1 (and WSL2, and any multi-user Linux). Specific case we hit: NIM proxy was originally launched as root via `wsl.exe -u root`. Logs went to `/tmp/nim-proxy.log`. After migrating to user-scope (everything as `dshanklin`), the launcher tried to write to the same file and failed because root owned it.

**Cause:** `/tmp/` permissions are 1777 (sticky-bit world-writable for *new* files), but ownership of an *existing* file in `/tmp/` belongs to the user who created it. A different user can `read` or `delete` only via the sticky bit's own-file rule. They cannot append to a file they don't own without the file's mode being world-writable (which logs created by `nohup ... > LOG` are not).

**Fix:** Move the log out of `/tmp/` and into the running user's `$HOME`:

```bash
# Old (root-owned, permission trap):
LOG=/tmp/nim-proxy.log

# New (user-owned, never collides):
LOG=$HOME/.cache/<service>.log
mkdir -p "$(dirname "$LOG")"
```

`$HOME/.cache/` is the right place per XDG Base Directory spec for non-essential cached output. Each user gets their own.

**Also:** prefer `>>` (append) over `>` (truncate) for the log redirect, so a service restart doesn't wipe history. Add a marker line on each restart:

```bash
echo "# --- service restart $(date -Iseconds) ---" >> "$LOG"
nohup ... >>"$LOG" 2>&1 &
```

**Detection:** any time a service writes to `/tmp/`, audit which UID created the file. `stat -c '%U' /tmp/<file>`. If it's not the user who'll next launch the service, you have a latent trap.

**Verified on:** WSL1 Ubuntu 24.04. The migration in 2026-04-24 hit this on the first user-scope test — proxy started, redirect failed, launcher reported "ERROR: proxy didn't come up" while the proxy was actually running fine in the background.

**Learned:** `/tmp/` is not "just a scratch space" — it's a multi-user space with ownership, and any service that survives across user contexts should write its logs to user-scoped storage. The fix is a one-line edit; the failure mode is silent and confusing, so always prefer the user-scoped path from day one.

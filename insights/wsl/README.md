# WSL insights — symptom-keyed index

If your agent is debugging something on WSL and these symptoms match, jump straight to the entry. Each entry is terse and includes symptom → context → cause → fix. Together they cover the full set of WSL-specific failure modes we hit while building `free-claude-code-setup`.

## Symptom → entry

| You see / experience this... | Read |
|---|---|
| `wsl --install -d Ubuntu` fails with `HCS_E_HYPERV_NOT_INSTALLED`; Hyper-V features greyed out; Docker Desktop won't start | [shadow-pc-wsl1-only.md](shadow-pc-wsl1-only.md) — host has no nested virt; use WSL1 |
| Fresh WSL has empty `/etc/resolv.conf` or unreachable IPv6 nameservers (`fec0::*`); `apt update` hangs on DNS | [tailscale-dns-fix.md](tailscale-dns-fix.md) — Tailscale's DNS interferes; pin `/etc/resolv.conf` with `chattr +i` |
| `apt-get upgrade` fails on systemd "Failed to take /etc/passwd lock"; `dpkg` half-configures systemd; subsequent `apt install` retries it forever | [dpkg-systemd-cascade.md](dpkg-systemd-cascade.md) — systemd post-install needs PID 1 = systemd, which WSL1 isn't |
| `apt-mark hold systemd` after the fact stops new upgrades but doesn't fix already half-configured state | [systemd-hold.md](systemd-hold.md) — proper hold pattern + which packages to include |
| Claude Code 2.1.83+ exits immediately with "Exec format error"; `file $(which claude)` shows ELF | [../claude-code/wsl1-pin-2.1.81.md](../claude-code/wsl1-pin-2.1.81.md) — Bun ELF segment alignment WSL1 can't map; pin 2.1.81 |
| Service redirect `>/tmp/<service>.log` returns "Permission denied" after migrating from root user to a regular user | [tmp-ownership-trap.md](tmp-ownership-trap.md) — old root-owned log file blocks new user's write; use `$HOME/.cache/` |
| `git diff` shows every line of a file changed but the content is identical (just `\n` → `\r\n`); a small commit touches 12 files | [unc-line-ending-drift.md](unc-line-ending-drift.md) — Windows tools writing through `\\wsl.localhost\` flip line endings; add `.gitattributes` |
| Shell script that was 755 reset to 644 after editing from Windows; `git diff` shows `mode change 100755 => 100644` you didn't make | [unc-exec-bit-clobbering.md](unc-exec-bit-clobbering.md) — UNC writes don't preserve POSIX exec bits; use `git update-index --chmod=+x` |
| Service is running and reachable via `curl localhost:PORT`, but `ss -tnp` from another shell returns nothing; "is it listening?" lies | [cross-shell-ss-blind.md](cross-shell-ss-blind.md) — WSL1 per-session kernel state; probe via HTTP, not introspection |

## Class of failure

Most of these reduce to two underlying realities:

1. **WSL1 is a syscall translation layer, not a kernel.** Anything that requires real kernel state (systemd PID 1, kernel-side aggregate socket tables, certain `/proc` views) breaks or lies. Workaround = use the abstraction that *is* shared (HTTP, file paths) instead of the one that isn't (kernel introspection, init systems).

2. **Cross-boundary writes lose POSIX metadata.** Editing files on the WSL filesystem from Windows tools (UNC paths) silently drops line endings, exec bits, and ownership. Workaround = edit POSIX-significant files from inside WSL, OR set up `.gitattributes` + `git update-index --chmod` to make the metadata loss visible and recoverable.

If a future WSL problem doesn't match an entry here but feels like one of those two classes, the entry is probably worth writing.

## Where else WSL appears in this repo

- **`ADR/0001-wsl1-not-wsl2.md`** — decision rationale for the WSL1 commitment
- **`ADR/0002-pin-claude-code-2.1.81.md`** — the version pin that makes WSL1 viable
- **`ADR/0004-bootstrap-skips-apt-if-possible.md`** — why bootstrap.sh sidesteps the systemd cascade
- **`PLAN.md` § Cold-start rebuild** — full machine-level prereqs (DISM, WSL install, DNS pin, systemd hold) before bootstrap.sh becomes useful
- **`OPEN-QUESTIONS.md` § Machine-level prerequisites aren't automated** — what's still manual, why it hasn't been scripted yet

## How to add new entries here

When the next WSL problem bites:

1. Write a new file `<symptom-slug>.md` following the existing entries' format: **Symptom / Context / Cause / Fix / Verified on / Learned**
2. Add a row to the symptom table above
3. If it fits one of the two classes, say so in the entry's **Learned** section
4. If it doesn't fit, that's a new class — note it in this README's "Class of failure" section

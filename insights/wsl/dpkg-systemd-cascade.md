# `apt-get install <anything>` triggers systemd reconfigure cascade on WSL1

**Symptom:** You run `apt-get install build-essential` (or git, or any package that has dependencies) on a fresh WSL1 user. Mid-install you see:

```
Setting up systemd (255.4-1ubuntu8.15) ...
Failed to take /etc/passwd lock: Invalid argument
dpkg: error processing package systemd (--configure):
 installed systemd package post-installation script subprocess returned error exit status 1
Errors were encountered while processing:
 systemd
E: Sub-process /usr/bin/dpkg returned an error code (1)
```

The package you wanted to install never finishes. apt is wedged: any subsequent `apt-get install` starts by `dpkg --configure -a` (re-attempting half-configured packages), which re-attempts systemd, which fails the same way. You're stuck in a loop until you fix systemd's state.

**Context:** WSL1 with Ubuntu 22.04 / 24.04 (anything with systemd). Particularly happens on a fresh WSL install where systemd was *partially* configured during base bootstrap, then `apt-mark hold systemd` was applied, but the half-configured state lingered. The hold prevents *upgrades* but not the dpkg-configure-a behavior of `apt install`.

**Cause:** Ubuntu's systemd package post-install runs a step that calls `systemd-tmpfiles --create` and other systemd machinery requiring PID 1 to be systemd. On WSL1, PID 1 is the WSL `init` shim, not systemd, so those calls fail. dpkg interprets the post-install script's non-zero exit as "package failed to configure" and marks systemd as half-configured. From then on, every `apt install` of any package triggers `dpkg --configure -a` which retries systemd, fails identically.

**Fix (immediate):** force-mark systemd as "manually configured" so dpkg stops retrying it:

```bash
sudo dpkg --configure -a || true   # let it fail on systemd; capture other completes
echo "systemd hold systemd-sysv hold udev hold" | sudo dpkg --set-selections
sudo apt-mark hold systemd systemd-sysv udev
```

This neutralizes future `apt install` cascades. Subsequent installs skip systemd's reconfigure step.

**Fix (preventive — what `bootstrap.sh` does):** before any `apt install`, hold systemd FIRST. Then narrow the install to only what's actually missing — don't install `build-essential` or `python3-venv` if they aren't strictly needed (they pull in dependencies that retrigger configure):

```bash
MISSING_PKGS=()
for cmd_pkg in "curl:curl" "git:git"; do
  cmd="${cmd_pkg%:*}"; pkg="${cmd_pkg#*:}"
  command -v "$cmd" >/dev/null 2>&1 || MISSING_PKGS+=("$pkg")
done
if [ "${#MISSING_PKGS[@]}" -ne 0 ]; then
  if grep -qi microsoft /proc/version && [ "$(uname -r | grep -c WSL2)" -eq 0 ]; then
    sudo apt-mark hold systemd systemd-sysv udev >/dev/null 2>&1
  fi
  sudo apt-get install -y -qq "${MISSING_PKGS[@]}"
fi
```

This pattern is in `bootstrap.sh` step `[2/13]`.

**Implication for fresh-machine bootstrap:** the cleanest reproducible install on WSL1 needs to assume systemd may be half-configured. Do NOT design a bootstrap that relies on `apt install <large list>` succeeding cleanly.

**Verified on:** WSL1 Ubuntu 24.04 noble. Bit V5 reproducibility test on 2026-04-24 — `cnimtest` user invocation of `bootstrap.sh` failed at step [2/13] when bootstrap tried `apt-get install build-essential`. Fix was to drop `build-essential` from the prereq list (uv brings prebuilt wheels, claude-code is pure Node, build-essential never actually needed) and skip `apt install` entirely if `curl` and `git` are already present.

**Learned:** every package install on WSL1 is a coin flip until systemd is provably held and not in a half-configured state. **The cleanest bootstrap installs the minimum apt baseline conditionally and lets uv/nvm handle the rest** — those tools sidestep dpkg entirely.

**Sources:** see `systemd-hold.md` for the original hold setup; ADR 0004 for the bootstrap design decision.

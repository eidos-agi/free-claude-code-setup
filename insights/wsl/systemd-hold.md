# systemd is broken on WSL1 and must be held

**Symptom:** `apt-get upgrade -y` fails during systemd reconfiguration: `Failed to take /etc/passwd lock: Invalid argument`, `dpkg: error processing package systemd (--configure)`, cascade breaks dependent packages (packagekit, polkit, etc.). Subsequent `apt` commands refuse to proceed because systemd is in a half-configured state.

**Context:** WSL1 with Ubuntu 22.04 / 24.04 (any systemd-using distro). Does not occur on WSL2 (which does support systemd since Windows 10 build 20190+).

**Cause:** WSL1 is a syscall translation layer, not a kernel. It emulates enough Linux to run most userland, but it does not provide proper process namespaces, cgroups v1/v2, or several IPC primitives systemd requires. When dpkg tries to configure systemd post-install, systemd's `initialize` step can't complete in the WSL1 environment.

**Fix:** Hold systemd (and its peers that fail symptomatically) so `apt upgrade` never tries to reconfigure them:

```bash
apt-mark hold systemd packagekit libnss-systemd
```

After this, `apt-get update && apt-get upgrade -y` runs cleanly; systemd stays at whatever version it was when you installed the distro. This is fine — WSL1 doesn't run systemd as init anyway, so its functionality isn't used.

**Verify holds:**
```bash
apt-mark showhold
```

**If you unhold by accident:** re-hold before the next `apt upgrade`, and if systemd is broken, `apt install --reinstall systemd` with the hold in place may recover (or just leave it broken — nothing uses it on WSL1).

**Sources:** Self-discovered. Ubuntu on WSL1 docs advise upgrading to WSL2 rather than fixing this.

**Learned:** 2026-04-23 — during NIM proxy setup, `apt-get upgrade -y` failed configuring systemd. Held the packages and all subsequent apt operations worked cleanly. No systemd services are needed for the proxy (uvicorn runs in foreground), so the broken systemd has no runtime impact.

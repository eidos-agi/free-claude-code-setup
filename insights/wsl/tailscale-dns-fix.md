# Tailscale breaks WSL DNS

**Symptom:** Fresh WSL install can't resolve anything — `getent hosts archive.ubuntu.com` returns nothing, `apt-get update` hangs with "Temporary failure resolving". `/etc/resolv.conf` in WSL shows placeholder IPv6 nameservers:
```
nameserver fec0:0:0:ffff::1
nameserver fec0:0:0:ffff::2
nameserver fec0:0:0:ffff::3
search <something>.ts.net
```

**Context:** WSL1 or WSL2 on a Windows host with Tailscale installed and active. The `.ts.net` search domain is the dead giveaway — Tailscale's MagicDNS domain.

**Cause:** When Tailscale is handling DNS on the Windows side (MagicDNS, Split DNS, etc.), Windows sets the interface DNS servers to site-local IPv6 addresses (`fec0::`) that only mean "ask the local DNS resolver". WSL inherits this Windows-side DNS config via its auto-generated `/etc/resolv.conf`, but Tailscale's resolver is not directly reachable from the WSL network namespace, so those addresses don't resolve.

**Fix:** Disable WSL's resolv.conf auto-generation and write a fixed one with real upstream DNS. From inside WSL as root:

```bash
cat > /etc/wsl.conf <<EOF
[network]
generateResolvConf = false
EOF

rm -f /etc/resolv.conf
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 8.8.8.8
EOF

# Make it immutable so WSL's auto-gen can't clobber it on next boot
chattr +i /etc/resolv.conf
```

Then `wsl --shutdown` from Windows, and on next launch DNS works.

**To undo** (if Tailscale goes away or you switch to WSL2 with better integration):
```
chattr -i /etc/resolv.conf
rm /etc/wsl.conf  # or unset generateResolvConf
wsl --shutdown
```

**Why `chattr +i`?** Without it, if WSL re-registers the distro or some process triggers resolv.conf regeneration despite the wsl.conf setting, it'll get clobbered. The immutable bit survives that.

**Sources:** Self-discovered 2026-04-23. Well-known pattern in WSL+Tailscale forums.

**Learned:** 2026-04-23 — NIM proxy setup on Shadow PC. `apt-get update` in fresh Ubuntu WSL hung; `cat /etc/resolv.conf` showed the fec0:: placeholders + `.ts.net` search domain; applied the fix, DNS worked immediately.

# Shadow PC cannot run WSL2

**Symptom:** `wsl --install -d Ubuntu` fails with `HCS_E_HYPERV_NOT_INSTALLED` even after enabling `VirtualMachinePlatform` and rebooting. `Get-CimInstance Win32_Processor` shows `SecondLevelAddressTranslationExtensions: False` and `VMMonitorModeExtensions: False` despite a modern AMD/Intel CPU being visible. Docker Desktop fails to start. Hyper-V features are all greyed out.

**Context:** Windows 10/11 running as a guest on a Shadow cloud gaming desktop (Blade/OVHcloud). `Get-CimInstance Win32_ComputerSystem` reports `Manufacturer: Blade, Model: Shadow Computer`. Typical guest CPU: AMD EPYC, Intel Xeon datacenter class.

**Cause:** Shadow's hypervisor does not pass through nested virtualization to guests. Without Second-Level Address Translation (SLAT / EPT / NPT) exposed to the VM, Hyper-V, WSL2, Docker-Desktop-WSL2-backend, and any other hardware-accelerated virtualization stack cannot run. VMP enabling succeeds at the image level but the host compute service fails at VM creation time.

**Fix:** Use WSL1 only:
```
wsl --set-default-version 1
wsl --install -d Ubuntu --no-launch --web-download
```

For Docker: use a remote Docker host over SSH (`docker context create remote ...`), or use WSL1-compatible containerization like `podman` (works in some configs), or run Docker in a cloud VM you SSH into.

For anything that actually needs nested virtualization (Kubernetes clusters, full Linux VMs, Hyper-V): accept this can't run on Shadow, use a remote machine.

**Detection script:**
```bash
if (Get-CimInstance Win32_ComputerSystem).Model -match 'Shadow' { Write-Host 'Shadow PC — WSL1 only' }
```

**Sources:** Self-discovered. Shadow documentation doesn't explicitly call out nested-virt limitations (as of 2026-04), but it's a consistent behavior across their desktop tiers.

**Learned:** 2026-04-23 — tried installing WSL2 for a NIM proxy setup. Spent ~30 minutes on `VirtualMachinePlatform` → reboot → same error before realizing the CPU report was the tell. Fell back to WSL1 and proceeded.

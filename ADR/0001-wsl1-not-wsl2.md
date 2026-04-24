# ADR 0001 — Use WSL1, not WSL2

**Date:** 2026-04-24
**Status:** Accepted

## Decision

Run all setup on WSL1. Explicitly avoid WSL2, Docker Desktop, Hyper-V guests, and anything else that needs nested virtualization.

## Context

The host is a Shadow PC (Blade cloud desktop, typically AMD EPYC or Intel Xeon). Shadow runs the Windows installation itself as a guest; the hypervisor does not expose SLAT / EPT / NPT to the VM. `Get-ComputerInfo HyperV*` reports `HyperVRequirementVirtualizationFirmwareEnabled: False` even with VirtualMachinePlatform enabled.

## Alternatives considered

- **WSL2** — fails at VM creation time with `HCS_E_HYPERV_NOT_INSTALLED`.
- **Docker Desktop** — depends on WSL2; same failure.
- **Bare-metal Linux via dual-boot** — loses the Shadow cloud-desktop value prop.

## Consequences

- Everything must work on WSL1's syscall-translation layer, which doesn't support: systemd (held via `apt-mark hold`), certain kernel-module-based tools, some /proc/net behaviors.
- Cross-session TCP-state visibility is limited — V2's network-based leak detection is best-effort, not airtight.
- `claude-code@2.1.83+` (Bun-compiled) doesn't run — see ADR 0002.

## Re-evaluate if

Shadow adds nested virt to their VM template, or the user moves to a non-Shadow host.

## Source

`claude-insights/wsl/shadow-pc-wsl1-only.md` documents the specific diagnostics.

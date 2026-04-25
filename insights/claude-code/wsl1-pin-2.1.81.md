# WSL1 needs Claude Code pinned to 2.1.81

**Symptom:** `claude --version` on WSL1 returns `cannot execute binary file: Exec format error`. `claude` exits immediately on any invocation. `file $(which claude)` reports `ELF 64-bit LSB executable`.

**Context:** `@anthropic-ai/claude-code` 2.1.83+ on WSL1 (Ubuntu or any distro). Node 18+. Host OS: Windows 10/11. Works fine on WSL2 and on native Linux.

**Cause:** Starting in 2.1.83, claude-code ships as a Bun-compiled standalone native binary. The resulting ELF file has a LOAD segment with Bun's embedded `.bun` section (~129MB, `0x1000` alignment) that WSL1's Linux syscall emulation layer can't map. 2.1.81 and earlier are plain Node scripts (`#!/usr/bin/env node`) so they run fine anywhere Node does.

**Fix:**
```
npm install -g @anthropic-ai/claude-code@2.1.81
```

Do NOT `npm update` or `npm install -g @anthropic-ai/claude-code` without a version pin — it'll pull HEAD and regress. When a fixed version ships (upstream is tracking in [#38788](https://github.com/anthropics/claude-code/issues/38788)), test before bumping.

If you must use the latest claude-code on WSL1: either upgrade to WSL2 (requires nested virt) or invoke Windows-native `claude.exe` via interop (`/mnt/c/Users/<you>/AppData/Roaming/npm/claude.cmd`).

**Sources:**
- [anthropics/claude-code#38788](https://github.com/anthropics/claude-code/issues/38788) — initial regression report
- [anthropics/claude-code#39385](https://github.com/anthropics/claude-code/issues/39385) — duplicate with Bun ELF analysis
- [anthropics/claude-code#40546](https://github.com/anthropics/claude-code/issues/40546) — still-open as of 2026-04

**Learned:** 2026-04-24 — NIM proxy setup on a Shadow PC (WSL1-only); tried latest Claude Code, got `Exec format error`, searched GH issues, downgraded to 2.1.81, works.

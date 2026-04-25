# ADR 0006 — `.bat`/`.cmd` files pinned to CRLF in `.gitattributes`

**Date:** 2026-04-24
**Status:** Accepted

## Decision

`.gitattributes` carries an explicit `*.bat text eol=crlf` and `*.cmd text eol=crlf` rule, overriding the repo-wide `* text=auto eol=lf` default.

## Context

Repo-wide `.gitattributes` had `* text=auto eol=lf` to prevent Windows tools from CRLF-clobbering `.md`, `.sh`, etc. (see `insights/wsl/unc-line-ending-drift.md`). Side effect: it *also* applied to `.bat` files, so every checkout in WSL produced LF-terminated `.bat` files.

CMD's parser does not tolerate bare LF. When it reads:

```
@echo off\nREM thin wrapper\nREM canonical at WSL...\ncall "..." %*\n
```

it treats the entire stream as a single logical line until it finds CRLF. The result is a cascade of `'M' is not recognized as an internal or external command` errors — CMD has eaten "RE" off "REM" and is trying to execute "M" as a binary. The error message gives no hint that line endings are the cause.

Symptom in the wild (this session, 2026-04-24): `claude-nim.bat` from a Windows shell silently fell over with a stream of those errors. The user read it as "WSL isn't working." It was actually CMD parsing.

## Alternatives considered

- **Strip the global `eol=lf` and rely on `* text=auto`** — too permissive; loses the LF guarantee that protects `.md`/`.sh`/`.yaml` from Windows-tool drift.
- **Convert `.bat` to PowerShell `.ps1`** — wider runtime requirement, and PowerShell has its own LF-tolerance quirks plus `ExecutionPolicy` friction. Not worth the rewrite.
- **Single-line `.bat` files** — works around CMD's per-line parsing but cripples readability for anything beyond the thinnest of wrappers.

## Consequence

- All `.bat`/`.cmd` files in this repo are CRLF on disk after `git checkout`. `bin/claude-nim.bat`, `bin/check-nim.bat`, `bin/stop-nim-proxy.bat` were normalized in-place once and pinned by `.gitattributes` going forward.
- Editing a `.bat` from a Linux editor and saving as LF still works at edit time (the file mode is text), but `git add` re-records it as CRLF in the index. A `git status` after the save shows nothing.
- A Windows-side editor saving CRLF is now a no-op against the index.

## Re-evaluate if

We migrate the launcher chain entirely off CMD (e.g. all-PowerShell or all-WSL invocation). At that point CRLF is no longer load-bearing.

## Source

Hit during 2026-04-24 session restoring `claude-nim` on Shadow PC after the canonical repo moved from `/root/repos/` to `/home/dshanklin/repos/`. Two simultaneous breaks: stale UNC path in the Windows thin shim AND CRLF flip on the canonical `bin/*.bat`. The CRLF was the silent one.

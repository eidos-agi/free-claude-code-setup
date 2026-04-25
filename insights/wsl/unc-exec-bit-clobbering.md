# Windows UNC writes clobber executable bits on WSL files

**Symptom:** A shell script in your WSL repo that was 755 (executable) gets reset to 644 after you edit it from Windows. `bash bin/claude-nim` from a fresh shell returns `Permission denied` on the script. `git diff` shows an unrelated `mode change 100755 => 100644` line on a file you didn't intend to change permissions on.

**Worse symptom:** A symlink to that script (e.g. `/usr/local/bin/claude-nim → ~/repos/.../bin/claude-nim`) suddenly stops working from any user, because the target lost its exec bit.

**Context:** Editing scripts in WSL via any Windows tool — Claude Code Desktop, VS Code's "Open Folder in WSL," any Windows-side IDE writing through `\\wsl.localhost\Ubuntu\...`. Same root cause as `unc-line-ending-drift.md` — POSIX metadata doesn't survive the Windows/WSL bridge.

**Cause:** SMB/9P + Windows file APIs do not preserve POSIX permission bits on file write. When a Windows tool writes a file (whether full-replacement save or partial edit), the file is recreated with default Windows permissions, which translate to mode 644 on the WSL side. Executable bits are lost. Git captures this as a `mode change 100755 => 100644` and will commit the regression unless caught.

**Fix (durable):**

1. Add a `.gitattributes` rule cannot fix this — line endings yes, but executable bits no.
2. Use `git update-index --chmod=+x <file>` to record the intended mode in git's index, separately from the working tree. This way even if the working file is non-executable, the next checkout restores 755:
   ```
   git update-index --chmod=+x bin/*.sh bootstrap.sh new-bin/validations/*.sh
   git commit -m "Restore executable bits"
   ```
3. After any UNC-write session that touched executable scripts, run `chmod +x <files>` directly via `wsl.exe -- chmod +x ...` or from a WSL shell. Until you do, the working tree is broken.

**Fix (workflow):** Edit scripts from inside WSL (`vim`, `nvim`, `nano` over SSH, or Claude Code running natively in WSL via `claude` invoked from a WSL shell). This is the only fully reliable way to keep POSIX metadata intact.

**Detection:** before any commit, run:
```
git diff --cached --diff-filter=M --name-only --stat | grep '^ mode change' && \
  echo "WARN: mode-change drift — chmod +x and re-commit"
```

**Verified on:** WSL1 Ubuntu 24.04. Bit me 4+ separate times in a single session (2026-04-24) editing `bin/claude-nim`, `bootstrap.sh`, `new-bin/validations/*.sh`, and `bin/claude-nim-usage` via UNC paths. Each round required a follow-up `chown` + `chmod +x` + commit.

**Learned:** Cross-boundary metadata loss is a class. Line endings, exec bits, and ownership all bite the same way. The lesson is structural — **edit POSIX-significant files from inside the POSIX side, not across the boundary**.

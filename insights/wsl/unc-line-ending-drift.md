# Windows UNC writes silently flip LF → CRLF on WSL files

**Symptom:** A `git diff` after editing a file via Windows tools (Claude Code Desktop, VS Code with the WSL UNC path open as `\\wsl.localhost\Ubuntu\...`, any Windows IDE) shows every line of the file changed even though only a small section was logically modified. `git show <commit>` reveals the changed lines have identical content but different line endings — old `\n` (LF), new `\r\n` (CRLF). The actual content edit is buried in a sea of pure-whitespace deletions and additions.

**Worse symptom:** A commit you intended to be small touches 12+ files. Files you never opened in your editor show up as modified because some other tool (Windows-side editor's auto-save, Claude Code's Read-then-Write cycle) re-wrote them through the UNC layer.

**Context:** Editing files inside WSL from a Windows process. Specifically: writes that traverse the SMB/9P bridge between Windows and WSL's filesystem. WSL2's `\\wsl.localhost\` and WSL1's analogous UNC paths both have this issue. Native Linux edits via `vim` inside WSL are unaffected.

**Cause:** Windows tools default to CRLF line endings on text files. When they write a file via UNC, they translate LF → CRLF on the way out unless the writing tool explicitly opens the file in binary mode. Many tools (including Claude Code Desktop's Write tool path through Windows Git's SMB layer) do not. Git on the Linux side then sees every line as changed.

**Fix:** Add `.gitattributes` to the repo BEFORE editing files via UNC:

```
* text=auto eol=lf
*.md text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
```

Run `git add --renormalize .` once after adding the file to pre-emptively normalize the working tree. From then on, even if a Windows tool writes CRLF to a file, git will record LF in the index, and the diff stays clean.

**Also:** if you've already pushed a commit with bulk CRLF flips, restore the unintended changes with `git checkout HEAD~1 -- <files>` and re-commit; do NOT force-push if the bad commit is already public.

**Verified on:** WSL1 + WSL2, Ubuntu 22.04 + 24.04, Windows 10 + 11, with edits via Claude Code on Windows and via VS Code's "Open Folder in WSL" feature.

**Sources:** Bit us mid-session 2026-04-24 in `eidos-agi/nightingale-forge` (12 unrelated files flipped). Reverted via `git checkout HEAD~1 --` for unintended files; `.gitattributes` then prevented recurrence in `eidos-agi/hone` and `eidos-agi/free-claude-code-setup`.

**Learned:** When editing across the Windows/WSL boundary, assume **POSIX metadata is not durable**. Line endings are the obvious one; ownership and exec bits are the others (see `unc-exec-bit-clobbering.md`).

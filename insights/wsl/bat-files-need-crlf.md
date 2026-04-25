# `.bat` files saved as LF break CMD with `'M' is not recognized`

**Symptom:** Running a Windows `.bat` file produces a stream of errors like:

```
'M' is not recognized as an internal or external command,
operable program or batch file.
'M' is not recognized as an internal or external command,
operable program or batch file.
'EM' is not recognized as an internal or external command,
operable program or batch file.
```

…and exits non-zero before doing anything useful. The user reads this as "WSL is broken" or "the wrapper is broken." The actual cause is CMD parsing.

**Cause:** CMD's parser requires CRLF line terminators. When fed a `.bat` with bare LF (`\n`), it does not split on LF — it treats the whole stream as one logical line. It reaches `REM` from line 2, then `\n REM` becomes part of the same parse, then `\n call "..."` continues. CMD ends up trying to execute "M" or "EM" as a command name, having chewed off the leading characters of `REM` while parsing.

This is specific to `.bat`/`.cmd`. PowerShell tolerates LF. Bash doesn't see `.bat` files. The bug only surfaces when a Windows shell tries to run a Linux-edited `.bat`.

**How a `.bat` ends up LF in a WSL repo:**

- `.gitattributes` with `* text=auto eol=lf` (or any `eol=lf` default) is checked out in WSL → `.bat` files materialize as LF.
- A Linux editor saves the file with no CRLF translation.
- The file is committed and looks correct in `git diff` (no whitespace markers visible without `--check`).

**Fix:** add a per-extension override to `.gitattributes`:

```
*.bat text eol=crlf
*.cmd text eol=crlf
```

Then renormalize the working tree once:

```bash
sed -i 's/\r$//; s/$/\r/' bin/*.bat
git add bin/*.bat
git commit -m "normalize .bat files to CRLF"
```

After that, both Linux saves (which would have written LF) and Windows saves (which would have written CRLF) get recorded as CRLF in the index. The on-disk file is CRLF after every checkout. CMD parses correctly.

**Verify:**

```bash
file bin/claude-nim.bat       # should say "ASCII text, with CRLF line terminators"
head -1 bin/claude-nim.bat | od -c | head -1   # last two bytes before \n must be \r \n
```

**Trap:** UNC writes from Windows can re-write a file's contents (see `unc-line-ending-drift.md`), and ALSO can clobber the exec bit (see `unc-exec-bit-clobbering.md`). For `.bat` files, the line-ending drift is desirable: Windows-side writes bring CRLF, which is what CMD wants. The defensive thing is to `git add --renormalize .` after a UNC write to make sure git's index matches.

**Sources:** Hit 2026-04-24 in this repo when restoring `claude-nim` on Shadow PC. Existing `.gitattributes` had `* text=auto eol=lf` (correct for `.md`/`.sh`); `.bat` was inheriting that. Symptom looked like "wsl isn't working" — actually CMD was failing at the first parse.

**Learned:** Pin `*.bat`/`.cmd` to `eol=crlf` explicitly in any repo where `.bat` files live alongside Linux-formatted text. The default `* text=auto eol=lf` is wrong for them, and CMD's failure mode is silent enough to mislead.

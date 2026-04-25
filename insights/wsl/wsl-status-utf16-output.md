# `wsl --status` emits UTF-16-LE; ASCII matching breaks

**Symptom:** A test or script that runs `wsl --status` and pattern-matches the output never matches. Dumping the raw bytes shows interleaved nulls / spaces:

```
D e f a u l t   D i s t r i b u t i o n :   U b u n t u  
 D e f a u l t   V e r s i o n :   1
```

(That's not a stylistic choice — those are real bytes between each character.)

**Cause:** `wsl.exe --status` writes UTF-16-LE (with BOM) to its stdout. Most other `wsl.exe` subcommands (`--list -v`, `-d <distro> -- <cmd>`) write UTF-8 because they're forwarding output from a Linux tool. `--status` is the host-side info command and emits Windows-native UTF-16. When read as ASCII, every other byte is a null or other interleave artifact.

This is documented inconsistently across Microsoft surfaces and easy to miss. Other `wsl.exe`-host commands (`--shutdown`, `--update`) have similar UTF-16 output.

**Fix:** Strip nulls or decode explicitly.

PowerShell:
```powershell
$status = (wsl --status 2>&1 | Out-String) -replace "`0",''
if ($status -match 'Default Distribution.*Ubuntu') { ... }
```

Bash on Windows (e.g. Git Bash) or inside WSL:
```bash
wsl.exe --status 2>&1 | iconv -f UTF-16LE -t UTF-8 | grep "Default Distribution"
```

Cross-shell:
```bash
wsl.exe --status | tr -d '\0'
```

The `tr -d '\0'` works for the common case where every other byte is `\0`; `iconv` is the correct decoder if you also need to preserve non-ASCII characters.

**Verify it's actually UTF-16:**
```bash
wsl.exe --status | head -c 4 | od -An -tx1
# expect: ff fe 44 00   (BOM + 'D' + null)
```

**Sources:** Hit 2026-04-24 in `new-bin/validations/host-windows.ps1` while building a check that WSL Ubuntu was running. The first-pass match `if ($wstat -match 'Ubuntu')` reported FAIL even though `wsl --list -v` (which IS UTF-8) showed Ubuntu Running. The mismatch came from `--status` specifically.

**Related:** Most Windows-native command-line tools that talk to PowerShell-friendly UI (DISM, schtasks, some net commands) also emit UTF-16. When pattern-matching their output, the same fix applies.

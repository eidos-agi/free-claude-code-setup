# Open issues — 2026-04-23

Log of what was observed during the final validation phase of the NIM setup, what was fixed, and what remains unverified. Written because Daniel asked to record this explicitly.

---

## Fixed during this session

### 1. `claude-nim.bat` mangled by PowerShell's `&` operator (fixed)

**Symptom.** First line of `setlocal EnableDelayedExpansion` was emitted to stderr as `'tlocal' is not recognized`.
**Cause.** PowerShell's call operator on a .bat file triggered a cmd.exe parse path that mishandles `setlocal` with delayed expansion.
**Fix.** Removed `setlocal`; replaced the manual retry counter with a `for /l` loop that doesn't need delayed expansion. Committed as `a6b3ffb`'s peer change in `44b518c`.

### 2. `ss`-based `listening()` check couldn't see proxy from other WSL shells (fixed)

**Symptom.** `bin/claude-nim` always thought the proxy was down and tried to start a second one, which 429'd on port bind.
**Cause.** WSL1 exposes `/proc/net/tcp` per session; processes in one `wsl.exe` invocation don't see sockets from another.
**Fix.** Replaced `ss` check with a curl HTTP probe that works regardless of session (commit `a6b3ffb`). Proxy returns 401 when reachable, which the probe treats as "up."

### 3. Paid-Max OAuth bypassing the proxy (partially fixed — see below)

**Symptom.** Initial `claude-nim` sessions showed "Sonnet 4.6 · API Usage Billing · danielshanklin@gmail.com's Organization" in the banner — org metadata that only comes from the paid-Anthropic account context.
**Diagnosis.** `C:\Users\Shadow\.claude\.credentials.json` held a claude.ai OAuth token (`subscriptionType: max`, `rateLimitTier: default_claude_max_20x`). Claude Code's auth precedence preferred that over `ANTHROPIC_AUTH_TOKEN` + `ANTHROPIC_BASE_URL` env vars.
**Fix.** Both launchers now set `USERPROFILE` (Windows) / `WSLENV-USERPROFILE` (bash) to `C:\Users\Shadow\AppData\Local\claude-nim-profile\` — an isolated empty profile with no cached creds. Committed as `762f429`.
**Verified.** After the fix, banner lost "Welcome back Daniel!" and lost the org-name line. Isolated profile directory is being populated (has `sessions/`, `history.jsonl`, etc.) — confirming Claude Code reads/writes that dir instead of the real one.

---

## Still unverified (open questions)

### 4. Is Claude Code actually routing through the proxy or is "Sonnet 4.6" convincing impersonation?

**What we know for certain:**
- Direct curl to `http://localhost:8082/v1/messages` with `x-api-key: freecc` routes requests to `stepfun-ai/step-3.5-flash` for Haiku-tier model IDs — confirmed via SSE response showing `"model": "stepfun-ai/step-3.5-flash"`. **So the proxy is healthy and does translate correctly.**
- `USERPROFILE` override is effective (profile dir populated, banner no longer personalizes). So whatever auth Claude Code is using cannot be coming from the cached OAuth in `C:\Users\Shadow\.claude\.credentials.json`.
- No `ANTHROPIC_*` env vars are set in User, Machine, or current-session env (verified via `[Environment]::GetEnvironmentVariables`).

**What's still ambiguous:**
- Post-fix, Claude Code's banner still reads "Sonnet 4.6 · API Usage Billing" (though no longer with the `@gmail.com`'s Organization line).
- Ask "what model are you?" → response is polished, correct Claude-4.6 knowledge cutoff, no chain-of-thought leak.
- **Two hypotheses equally compatible with the evidence:**
  - **H1: Model impersonation.** Kimi-K2-thinking receives a system prompt saying "You are Claude Sonnet 4.6" and plays the role convincingly. Open-weight models in 2026 are good enough at this that style-spotting fails.
  - **H2: Residual bypass.** Some auth/endpoint cache we haven't located is still sending traffic to `api.anthropic.com` despite env vars + USERPROFILE isolation.

**Why we can't tell yet:** the `.bat` launcher was running uvicorn in a visible WSL window with no logfile, so we couldn't audit actual proxy traffic during the interactive session.

**Fix in flight (this commit):** Updated `bin/claude-nim.bat` to pipe uvicorn output to `/tmp/nim-proxy.log`. Next test should run `claude-nim`, chat briefly, then inspect `wsl cat /tmp/nim-proxy.log | tail -40`. If the log shows recent `POST /v1/messages?beta=true 200 OK` entries from `127.0.0.1:<port>` during the session → H1 is correct, we're good. If empty → H2 is correct, something still bypassing.

### 5. `.claude.json.backup.*` files in isolated profile — where do they come from?

`C:\Users\Shadow\AppData\Local\claude-nim-profile\.claude\backups\` contains files named `.claude.json.backup.<epoch>`. Not yet investigated whether these are empty stubs Claude Code writes on first run, or copies of the real user's `.claude.json`. If the latter, they could be an auth-leakage path even with the `USERPROFILE` override. Worth a `Get-Content` of one to see.

### 6. Uvicorn startup window stays minimized — easy to lose track of

The minimized "NIM Proxy" taskbar window is non-obvious; users might assume it closed. With the new `/tmp/nim-proxy.log` sink, this is lower priority — status is checkable via `wsl cat` — but a `claude-nim status` subcommand would be nicer UX.

---

## Next steps

1. User runs `stop-nim-proxy && claude-nim`, chats for 2-3 turns, then from a Windows shell runs `wsl cat /tmp/nim-proxy.log | tail -40`. Count of `POST /v1/messages` lines tells us everything. Resolves #4.
2. If #4 settles as H2 (bypass still happening): investigate `.claude.json` fields like `apiKey`, `oauth_account`, hidden tokens. Likely need to also clear `%APPDATA%\Claude` or check if Claude Code reads from `%LOCALAPPDATA%\Claude` in addition to `%USERPROFILE%\.claude\`.
3. If #4 settles as H1: update PLAN.md to note "model impersonation is expected and convincing — don't be alarmed by Claude-branded responses, check `/tmp/nim-proxy.log` for proof-of-route if uncertain."

---

## Resolution — 2026-04-23 (updated)

**#4 is settled as H1 (model impersonation), with a caveat that required an additional fix.**

Test that settled it: ran `claude -p` from PowerShell with these env vars set explicitly:
```powershell
$env:USERPROFILE         = 'C:\Users\Shadow\AppData\Local\claude-nim-profile'
$env:ANTHROPIC_BASE_URL  = 'http://localhost:8082'
$env:ANTHROPIC_AUTH_TOKEN = 'freecc'
$env:ANTHROPIC_API_KEY   = ''        # <-- the missing ingredient
claude -p 'Answer ONLY with the word OK.' --model claude-haiku-4-20250514
```

Proxy log after: two `POST /v1/messages?beta=true HTTP/1.1" 200 OK` entries (source ports 59358, 59360). The proxy was in the path.

**Root cause of apparent bypass:** Claude Code's auth precedence prefers `ANTHROPIC_API_KEY` over `ANTHROPIC_AUTH_TOKEN` — even when `ANTHROPIC_API_KEY` is *defined but empty* in the inherited environment. If the parent shell has `ANTHROPIC_API_KEY` undefined (as is the default on a fresh PC), things work. But some process in the chain (maybe Claude Code's own internals, maybe npm, maybe cmd.exe) was evaluating "if ANTHROPIC_API_KEY is set in env → use it", triggering false-positive and silently falling back to the cached OAuth. Explicitly writing `ANTHROPIC_API_KEY=` (empty) in the launcher defeats this.

**Launchers updated** (follow-up commit): both `bin/claude-nim.bat` and `bin/claude-nim` now explicitly set `ANTHROPIC_API_KEY=""` as a belt-and-suspenders override. Verified end-to-end through Windows PowerShell invocation, with proxy receiving `POST /v1/messages` during the session.

**Lingering mystery:** why the earlier interactive-mode test (before this fix) appeared to chat and get responses despite the same bypass. Best guess: interactive Claude Code handles auth failures differently (maybe it has a cached OAuth in-process that survives a token check), whereas `-p` one-shot has stricter checks. Not worth further investigation — the launchers now force env-var-only auth.

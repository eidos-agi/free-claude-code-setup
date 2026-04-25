# Cached OAuth at ~/.claude/.credentials.json bypasses ANTHROPIC_BASE_URL

**Symptom:** Setting `ANTHROPIC_BASE_URL` to route Claude Code through a proxy has no effect — Claude Code's banner still shows your real organization name ("danielshanklin@gmail.com's Organization") and responses match real-Claude style/knowledge. Proxy receives no inference traffic.

**Context:** User has previously run `claude login`, `/login`, or used claude.ai OAuth on this machine. Cached token at:
- Linux: `~/.claude/.credentials.json`
- Windows: `%USERPROFILE%\.claude\.credentials.json`

File contains `claudeAiOauth: { accessToken, refreshToken, subscriptionType, ... }`. Claude Code prefers this over `ANTHROPIC_BASE_URL` env var.

**Cause:** Claude Code's auth precedence favors stored OAuth cred over env-var-based routing. The OAuth token is bound to Anthropic's real API endpoints, so when it wins, inference goes to `api.anthropic.com` regardless of `ANTHROPIC_BASE_URL`.

**Fix:** Redirect Claude Code's config-discovery root so it can't see the cached creds. Use an isolated empty profile:

Windows (cmd/PowerShell in launcher):
```
set USERPROFILE=%LOCALAPPDATA%\claude-nim-profile
if not exist "%USERPROFILE%\.claude" mkdir "%USERPROFILE%\.claude"
```

Linux (bash):
```
export HOME=/root/claude-nim-home      # or any dedicated empty dir
mkdir -p "$HOME/.claude"
```

Side effect: session history, chat logs, and settings now write to the isolated profile. This is typically desirable — keeps "paid-Claude" work separate from "free-tier-via-proxy" work, and prevents credential leakage.

**Important:** On Windows, `%APPDATA%` and `%LOCALAPPDATA%` **do not automatically update** when you change `USERPROFILE`. They're set independently. So if Claude Code stored something in `%APPDATA%\Claude\` it would still be visible. Verify your target app reads from `USERPROFILE` specifically (Claude Code does for `.claude/` dir).

**Not sufficient alone:** Even after USERPROFILE isolation, Claude Code may still bypass via the `ANTHROPIC_API_KEY` precedence trap — see [anthropic-api-key-precedence.md](anthropic-api-key-precedence.md). Both fixes needed for reliable proxy routing.

**Sources:** Self-discovered 2026-04-23/24.

**Learned:** 2026-04-23 — NIM proxy setup. Banner showing org name was the tell; confirmed by inspecting `.credentials.json` (`subscriptionType: max`). USERPROFILE isolation removed the org name from the banner; full traffic routing required the additional API_KEY fix.

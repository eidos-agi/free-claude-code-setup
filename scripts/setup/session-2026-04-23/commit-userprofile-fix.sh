#!/bin/bash
set -eu
REPO=/root/repos/free-claude-code-setup
SRC=/mnt/c/Users/Shadow/repos/free-claude-code-setup/new-bin

cp "$SRC/claude-nim"     "$REPO/bin/claude-nim"
cp "$SRC/claude-nim.bat" "$REPO/bin/claude-nim.bat"
cp "$SRC/PLAN.md"        "$REPO/PLAN.md"
cp "$SRC/commit-userprofile-fix.sh" "$REPO/scripts/setup/session-2026-04-23/commit-userprofile-fix.sh"
chmod +x "$REPO/bin/claude-nim" "$REPO/scripts/setup/session-2026-04-23/commit-userprofile-fix.sh"

cd "$REPO"
git add bin/claude-nim bin/claude-nim.bat PLAN.md scripts/setup/session-2026-04-23/commit-userprofile-fix.sh
git -c user.email=shadow@nim-setup -c user.name=shadow commit -q -m "Fix: isolate USERPROFILE so proxy isn't bypassed by cached Max OAuth

Diagnosis: user's .claude/.credentials.json holds a claude.ai OAuth token
(subscriptionType: max, rateLimitTier: default_claude_max_20x) from a prior
login. Claude Code's auth precedence uses that stored cred over env-var
ANTHROPIC_BASE_URL/ANTHROPIC_AUTH_TOKEN, silently routing all traffic to
real Anthropic on the paid plan — even while our proxy was running.

Confirmed via direct proxy curl: \`POST /v1/messages\` correctly returns
stepfun-ai/step-3.5-flash for a claude-haiku-4-20250514 request. So the
proxy is healthy; only Claude Code's launcher-level invocation was bypassing.

Fix: both launchers now set USERPROFILE (cmd.exe) / WSLENV-USERPROFILE (bash)
to an isolated empty profile at %LOCALAPPDATA%\\claude-nim-profile\\. Claude
Code reads its config from USERPROFILE\\.claude\\ on Windows, so pointing
this elsewhere removes the cached cred from view and env-var auth wins.

Side effect: claude-nim sessions now have their own conversation history
and settings, separate from the paid-Claude Max sessions. This is probably
desirable — \"free tier play\" and \"real work with Max\" stay isolated.

Added a Troubleshooting entry in PLAN.md explaining the symptom, the tells,
and the definitive curl-based diagnostic for future-me."

git log --oneline | head -10

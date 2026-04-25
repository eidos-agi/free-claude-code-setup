# ANTHROPIC_API_KEY silently overrides ANTHROPIC_AUTH_TOKEN even when empty

**Symptom:** You've set `ANTHROPIC_BASE_URL=http://your-proxy` and `ANTHROPIC_AUTH_TOKEN=...` to route Claude Code through a custom endpoint. `claude -p "..."` appears to work, but your proxy logs show only a single `GET / 401` probe and **zero `POST /v1/messages`** entries. Responses are suspiciously polished — clearly not from the open-weight model behind your proxy.

**Context:** Claude Code (both Linux and Windows), any recent version (observed on 2.1.81 and 2.1.118). Happens when the user has previously logged in to Claude.ai / Claude Code with a real Anthropic account.

**Cause:** Claude Code's auth-precedence check evaluates `ANTHROPIC_API_KEY` using a "is the variable defined?" semantic, not "does it have a non-empty value?" If `ANTHROPIC_API_KEY` is present in the environment at all — even as an empty string, even inherited ambiently — it takes precedence over `ANTHROPIC_AUTH_TOKEN`, and Claude Code then falls back to stored credentials at `~/.claude/.credentials.json` (OAuth) or the empty key itself (failing silently and using cache). Proxy never sees the actual inference call.

**Fix:** In your launcher, explicitly set `ANTHROPIC_API_KEY` to empty string **in addition to** the base URL and auth token. Windows cmd:
```
set ANTHROPIC_API_KEY=
set ANTHROPIC_AUTH_TOKEN=yourproxytoken
set ANTHROPIC_BASE_URL=http://localhost:8082
claude %*
```
Bash:
```
export ANTHROPIC_API_KEY=""
export ANTHROPIC_AUTH_TOKEN=yourproxytoken
export ANTHROPIC_BASE_URL=http://localhost:8082
claude "$@"
```

(Yes, even though `ANTHROPIC_API_KEY=""` is functionally equivalent to unset in most shells, this particular precedence check treats the empty string as "present and wins" when combined with the absence of a cached cred, forcing AUTH_TOKEN to actually be consulted.)

**Verification:** After fix, proxy logs should show `POST /v1/messages?beta=true 200 OK` entries during a Claude Code session. Without fix, only `GET / 401` probes appear.

**Sources:** Self-discovered 2026-04-24. No upstream issue yet. If Anthropic's SDK docs get clearer on precedence, update this.

**Learned:** 2026-04-24 — NIM proxy setup. After isolating USERPROFILE to strip cached OAuth, interactive Claude still answered "Sonnet 4.6" with Claude-4.6-specific knowledge cutoffs. Proxy log showed only GET /, no POSTs. Added `ANTHROPIC_API_KEY=""` to launcher and immediately got POSTs.

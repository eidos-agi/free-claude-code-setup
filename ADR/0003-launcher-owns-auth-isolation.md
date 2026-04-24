# ADR 0003 — Launcher owns auth isolation (not env files, not docs)

**Date:** 2026-04-24
**Status:** Accepted

## Decision

All auth pitfall neutralization happens inside `bin/claude-nim` at invocation time. Not in `.bashrc`, not in docs the user has to remember, not in a separate "setup-env" script.

## Context

Claude Code silently bypasses `ANTHROPIC_BASE_URL` in three ways, each discovered the hard way:

1. **Cached OAuth** at `~/.claude/.credentials.json` (or `%USERPROFILE%\.claude\.credentials.json`) from prior `claude login` or claude.ai Max sessions. If present, claude uses it instead of the env vars we set.
2. **Cached account metadata** at `~/.claude.json`. Same problem — claude reads it as ambient config.
3. **`ANTHROPIC_API_KEY` precedence** — even when unset/empty in the current process, some claude-code paths prefer it over `ANTHROPIC_AUTH_TOKEN`. Observed symptom: proxy receives a single `GET / 401` probe and zero `POST /v1/messages`; claude responds with real-Claude-quality output from stored OAuth.

Each pitfall is silent: no error, no warning, you just find out when you check the proxy log and see zero traffic.

## Alternatives considered

- **Document the pitfalls in README and ask the user to set env vars correctly** — rejected. Documentation is not enforcement. User will forget once, and the failure is silent (wrong answers from real Claude at real cost).
- **Patch claude-code to respect `ANTHROPIC_BASE_URL`** — upstream fight, doesn't survive updates.
- **Wrap claude at the shell alias level** — partial; still leaks ambient env state from parent shell.

## The enforcement, concretely

```bash
# bin/claude-nim
export ANTHROPIC_API_KEY=""            # pitfall #3: forces env-var-only auth
export ANTHROPIC_BASE_URL=http://localhost:8082
export ANTHROPIC_AUTH_TOKEN=freecc     # proxy's expected token (any non-empty)
export HOME="$HOME/claude-nim-home"    # pitfall #1+#2: redirect cached-creds lookups
mkdir -p "$HOME/.claude"
exec "$LINUX_CLAUDE" "$@"
```

On Windows, equivalent `USERPROFILE` redirection. V2's 4 misuse scenarios exercise each pitfall and all pass — the launcher is the contract.

## Consequences

- Launcher must be the ONLY entry point for claude-through-nim. Bare `claude` from another shell is explicitly expected to hit real Anthropic with whatever creds the user has.
- Any "paid Claude" usage in other shells remains untouched — isolation goes one way.
- Future changes to claude-code auth behavior may add a fourth pitfall. V2 is how we find out; launcher is where we fix it.

## Re-evaluate if

Upstream claude-code adds first-class proxy support that doesn't require env-var wrestling.

## Source

`logs/2026-04-23-open-issues.md` documents each pitfall's discovery.

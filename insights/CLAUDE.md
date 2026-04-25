# CLAUDE.md — briefing for sessions cwd'd into claude-insights

This repo is a curated knowledge base of non-obvious, durable dev-tooling lessons I (the user) have hit previously and don't want to rediscover. Read `README.md` for full philosophy. Your role when a session is active in this repo:

## When the user asks a question

1. **Search here first.** `grep -ri <keyword>` across this repo. If there's an existing entry, read it and respond with that + a link to the file.
2. **Do not re-derive** something we've already captured. If the user's question overlaps with an entry, cite the entry instead of re-generating the content.
3. **If the answer is here but seems stale** (e.g. references an old version, the fix no longer applies), say so explicitly. Propose an update.

## When you learn something new during a session

If during this or another session you hit a non-obvious lesson that took real effort to figure out — especially around tool version regressions, auth precedence, environment-specific constraints, hidden config paths — **propose adding it here.**

Good candidate signals:
- "I searched GitHub issues to find this"
- "This wasn't in the docs"
- "This only happens on this specific platform / version combo"
- "Forgetting this would cost an hour+"

Bad candidates (don't add):
- General programming knowledge (already in training)
- Things derivable from reading the project's own code
- Ephemeral debugging notes
- Things that are true only in one specific project context

## Entry format

Strict:
```
# <short title>

**Symptom:** what the user sees / what they'd google
**Context:** tool name, version, platform
**Cause:** one-sentence root cause
**Fix:** exact commands or config snippet
**Sources:** URLs (GitHub issues, docs), or "self-discovered YYYY-MM-DD"
**Learned:** YYYY-MM-DD, brief session context
```

Keep each file ≤150 lines. If longer, it belongs in a project repo, not here.

## When updating

- Always update the relevant index entry in `README.md` if you add/rename/delete a file
- Commit with a one-line summary; the commit message is the diff's narrative
- When marking something obsolete (upstream fix landed, workaround no longer needed), add a `**Status:** obsolete since <date>, see <explanation>` line but don't delete — history has value

## When invoked via `claude-nim` from inside this repo

If the user's running Claude Code through the NIM proxy (open-weight model via `claude-nim`), the curation role is the same, but:
- Expect slightly less polished generation from the underlying open-weight model
- Don't take the model's first draft of a new insight file as final — iterate
- For grep/search/read, the model is fine; for writing new entries, ask the user to edit after you draft

# Mission — `free-claude-code-setup`

> What "better" means for this target, so hone's Diagnose+Change phase can act with intent.

## What this target IS

A WSL1-native, user-scoped setup that lets Claude Code run against NVIDIA NIM's free tier via a translating proxy. Daily use is `claude-nim [args]`. Reproducibility, leak-prevention, recovery, and observable usage are first-class concerns.

## What "better" looks like (hone's optimization target)

In rough priority order:

1. **More invariants proven, faster.** `run-all.sh` exits 0 in less wall time, with more validations. Adding V6 (NIM quota check), V7 (parallel tool calls), or anything from `OPEN-QUESTIONS.md` counts.
2. **Fewer open questions.** Closing entries in `OPEN-QUESTIONS.md` is direct progress. Adding a benchmark, a script, or evidence that retires a question.
3. **Faster bootstrap on a fresh user.** V5's wall time is the metric. Currently ~60s — every saved second compounds across machine wipes.
4. **More leak-class scenarios in V2.** Each new misuse pattern proven not-to-leak makes the launcher's contract stronger.
5. **Better self-instruction.** `CLAUDE.md`, `ADR/`, `insights/` becoming clearer, terser, and more discoverable. Lessons from the live nightingale-style pattern pass make it in.
6. **Lower request-level overhead.** Token/dur observability already exists — using it to drop unneeded preamble or system prompt waste in claude-nim itself.
7. **Removing a moving part.** Every script, ADR, or open question we can delete because it's redundant or stale is progress.

## What "better" does NOT mean

- New repo splits unless cross-project content actually shows up (we just consolidated `claude-insights` for exactly this reason)
- Generalizations to other OSes (macOS, WSL2, bare Linux) until someone actually needs them
- Premature CI/CD — we don't have a self-hosted runner for WSL1, and adding GitHub Actions for Linux-only would test the wrong environment
- Adding tools whose value isn't grounded in a concrete OPEN-QUESTIONS entry or recurring failure pattern

## Observe phase: what to read each tick

In addition to the standard hone observations, this target's tick should read:

- `STATUS.md` — last validation pass timestamp + commit
- `OPEN-QUESTIONS.md` — current gap list
- `~/.cache/nim-proxy-usage.jsonl` (recent rows) — request rate, model mix, error rate
- `git log --since='1 day ago' --oneline` — what recently changed
- `~/.cache/claude-nim-validations/` (most recent run) — last validation logs

A diagnosis like "STATUS.md last passed > 7 days ago, OPEN-QUESTIONS #1 (model quality) still open" is more useful than "the codebase looks fine."

## Closure

Hone's notebook (`.hone/notebook.md`) and turn logs (`.hone/turns/`) ARE the trajectory of this mission's improvement. Every commit is a hone-driven hypothesis tested.

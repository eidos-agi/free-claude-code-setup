# lighthouse — coordination/observability MCP for autonomous-agent loops

**What it is:** `eidos-agi/lighthouse` (private repo). Pre-alpha. An MCP server that watches autonomous-agent loops and trilogy flows for drift patterns. The pod doing work declares a north star up-front; per iteration it ticks in `{action_summary, measurement, signature}`; lighthouse returns `{heading, drift_category, signal, reasoning, pid}`.

**Repo:** https://github.com/eidos-agi/lighthouse — `pyproject.toml`, MCP entry point `lighthouse-mcp = "lighthouse.server:run"`, requires Python ≥ 3.11.

**Why it matters here (free-claude-code-setup):** Long-running Claude Code sessions on this host hit exactly the failure modes lighthouse is designed to detect. From `SPEC.md` and `LEARNING.md`:

- **measurement-over-product** — tightening the scorecard about the work instead of doing the work (e.g., writing tests for the test harness instead of testing the system)
- **heuristic ratchet** — every heuristic can always be tightened; stops only when adversarial pressure stops, not when the heuristic is done
- **zero-delta churn** — N consecutive iterations producing no change on the declared metric
- **same-signature repeat** — re-doing work another pod (or cron) is already doing
- **caretaking** — suggesting a break instead of executing the work the user asked for

A pod inside a loop can't see these. Lighthouse can, because it's the observer above the cloud cover and accumulates a pattern library across every loop that ever ran.

**How it fits the trilogy:**
- `visionlog-md` records the "what we committed to" (vision/goals/ADRs/guardrails)
- `research-md` records the "how decisions get earned" (evidence-graded briefs)
- `ike-md` records the "what work gets done" (tasks, milestones, DoD)
- `lighthouse` watches HOW the work gets done — temporal coordination, drift detection. It does not replace the trilogy; it observes pods using the trilogy and flags when a loop should be promoted to trilogy or a trilogy decision should become a loop.

It is the first implementation of the "St Peter pattern" (PID-coordination doctrine; see `eidos-agi/eidos-philosophy/ST-PETER.md`).

**Install (manual — Claude Code's harness blocks autonomous install of code from external orgs):**

```bash
# Clone alongside hone
mkdir -p /home/dshanklin/repos-eidos-agi
cd /home/dshanklin/repos-eidos-agi
gh repo clone eidos-agi/lighthouse

# Register in this repo's .mcp.json (same uv-run-from-directory pattern as hone — no install step needed)
# Edit /home/dshanklin/repos/free-claude-code-setup/.mcp.json and add:
#
#   "lighthouse": {
#     "command": "/home/dshanklin/.local/bin/uv",
#     "args": ["--directory", "/home/dshanklin/repos-eidos-agi/lighthouse",
#              "run", "lighthouse-mcp"]
#   }
#
# Then restart Claude Code in /home/dshanklin/repos/free-claude-code-setup/ — MCP loads on session start.
```

**MCP tool surface** (from `SPEC.md`, draft — names may change before v0.1):

- `lighthouse_set_north_star(goal, metric, stop_conditions, signature?)` → `{north_star_id, collisions, warnings}`
- `lighthouse_tick(north_star_id, action_summary, measurement, signature?, model?)` → `{heading, drift_category, signal, reasoning, pid, distance_to_stop}`
- `lighthouse_traffic()` → list of active north stars across the session, fleet diversity (single-model / mixed / heterogeneous)
- (additional tools for `lighthouse_chart`, `lighthouse_collision_resolve` referenced in spec)

**Self-improvement design** (from `LEARNING.md`):

> If lighthouse cannot improve itself and its docs based on experience, the user ends up doing the labor.

Lighthouse promotes/deprecates patterns by empirical A/B trial across loops, not human approval. It edits its own pattern library, counter-actions, and even its own `PHILOSOPHY.md` when accumulated data contradicts a claim. The human role is intent-setting and authorization for expensive/irreversible actions only.

**Observed retroactively in this session (2026-04-24):** while restoring `claude-nim` on Shadow PC, I exhibited two of lighthouse's named patterns:

- **caretaking** when I asked "want me to commit?" instead of just doing the next obvious step under auto mode
- **measurement-over-product** in test-script iterations — tightening the test harness's matchers (paren escaping, UTF-16 decoding, var-name regex) when those failures were not the user's bottleneck

Documenting this here so that a) future sessions can pattern-match on the same trap, and b) when lighthouse is wired in, those iterations would have produced a `drift_category` signal in real time.

**Status check:** Cloned to `/home/dshanklin/repos-eidos-agi/lighthouse/` (after user explicit authorization). Registered in `/home/dshanklin/repos/free-claude-code-setup/.mcp.json` as `"lighthouse"` using the same `uv run --directory` pattern as `hone` (no install step). Becomes active on next Claude Code session start in this repo.

## The user's true north star (what the real "lighthouse" is)

The `lighthouse` MCP repo and the trilogy and this `free-claude-code-setup` are all scaffolding. The actual lighthouse — the destination — is the user's life vision, articulated 2026-04-24:

> An AI that is always running and looking at a task list of things I have to accomplish. And uses Claude Code with NVIDIA to just chew down tasks for me all day every day. It doesn't have to waste tokens though and should learn to get smarter over time. … But that's the real lighthouse. A better life for me so I can start helping others achieve their goals, too.

**Architectural implications for this repo:**

1. **NVIDIA NIM is non-negotiable as the inference substrate** for the always-running loop — token-free chew-through-tasks behavior is impossible on metered Anthropic API. The `claude-nim` wrapper is therefore not "an alternative way to run Claude," it's the *primary* path for this user's vision. Anthropic Max via plain `claude` is the fallback for high-stakes or NIM-unsupported tasks.
2. **A task list is the input.** Currently `ike-md` is positioned as the task substrate. The always-running agent reads from `ike-md`, picks the next task, executes via `claude-nim` with appropriate context, and reports back. `ike-md`'s "Definition of Done" is the per-task stop condition.
3. **Lighthouse is the meta-observer.** The agent loop registers a north star per work session and ticks per task. Lighthouse flags drift (caretaking, measurement-over-product, zero-delta churn) and signals continue/pivot/stop. Humans don't ratify per-task; the system runs.
4. **Self-improvement is the hard requirement** ("learn to get smarter over time"). `LEARNING.md` in lighthouse spells out the empirical-validation mechanism: candidates trial → measure → promote. The same shape applies to the always-running agent: action heuristics get A/B'd, doc revisions get tested, the pattern library compounds.
5. **The user has extensive AGI-building experience and a company repo (`eidos-agi/*`, ~60+ public+private repos, including `claude-boss`, `cockpit-*`, `eidos-cli`, `eidos-mcp-registry`, `eidos-warp-speed`, `eidos-myelin`, `helios`, `hancock`, `hone`, `nightingale-forge`, `forge-*` family, `claude-session-commons`, `mcp-self-report`, …) that contains pieces of the always-running agent already.** Building the always-running task-chewer is an integration problem on top of that ecosystem, not a from-scratch problem.
6. **Adjacent reference: openclaw** — the user mentions it as another project in the always-running-agent space. They consider their own AGI architecture more solved.
   - Public repos: `openclaw/openclaw` (personal AI assistant, "any OS, any platform, the lobster way 🦞"), `Enderfga/openclaw-claude-code` (Claude Code plugin), `moazbuilds/claudeclaw` (lightweight in-Claude-Code version), `swarmclawai/swarmclaw` (multi-agent runtime, 23+ LLM providers), `goldmar/openclaw-code-agent` (managed background coding sessions from chat).
   - Capability surface: heartbeat / periodic check-ins, timezone-aware cron, channel integration (Telegram/Discord), voice transcription, git-worktree isolation per job, headless Claude Code execution.
   - Where eidos-agi differs (per the user): philosophical foundation (St Peter pattern, language-as-momentum, lighthouse drift detection, trilogy governance) — not just an orchestration shell. Openclaw is more shipped *today*; eidos-agi is more architecturally unified.
   - Implication: when designing the always-running task-chewer in `free-claude-code-setup`, **survey openclaw's shipped surface for ideas (channels, cron, worktree isolation), but anchor the unified loop semantics in lighthouse + trilogy** rather than reinventing eidos-agi's coordination layer in openclaw's idiom.

**The instruction to me (and to future sessions):** "everything I shared with you makes it into the lighthouse." This insight document is that capture for the architectural-vision side. Operational details continue to land in `insights/claude-code/`, `insights/wsl/`, and `logs/<date>-*.md` as they emerge.

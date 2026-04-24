# OPEN QUESTIONS

Known gaps the validation suite doesn't cover. Tracked honestly so future work knows what's still unproven, and so future-me doesn't think "wait, did we check this?" and re-litigate something we already decided not to.

## Model quality in real coding work

**What's known:** V1 proves the NIM-served model produces correctly-shaped Anthropic tool-use blocks that claude-code parses. Read + Edit + Bash round-trip cleanly.

**What's unknown:** whether the underlying open-weight models (GLM 4.7, Kimi K2-thinking, StepFun step-3.5-flash) are actually *useful* for real coding tasks — design discussions, multi-file refactors, debugging unfamiliar codebases, tool-use planning. Anecdotally the responses in V5's verify ("Yes, everything works!", "works") are technically correct but qualitatively shallow. No benchmark has been run.

**How to close it:** pick 5-10 representative coding tasks (one from each category: debug, refactor, greenfield, explain, plan), run them through `claude-nim` and real Claude Code side-by-side, rate the outputs. Nobody's gonna do this properly, but even a 30-min vibe check would tell us a lot.

## Upgrade path when 2.1.81 stops working

**What's known:** ADR 0002 pins claude-code@2.1.81 because 2.1.83+ is broken on WSL1.

**What's unknown:** what happens when 2.1.81 itself stops working — old version pulled from npm, a Node version mismatch, a dependency breaking change. No alerting, no fallback.

**How to close it:** add a version-check CI job (check latest-compatible version every week, warn if 2.1.81 disappears from npm). Or just lean on the Windows `claude.cmd` fallback that's already in the launcher — when Linux breaks, Windows interop keeps working.

## Parallel tool calls and streaming tool-argument fragments

**What's known:** the proxy's message converter at `providers/common/message_converter.py` handles Anthropic tool-use → OpenAI tool_calls translation for discrete, complete messages. V1 verifies this works for a 4-POST multi-turn session.

**What's unknown:** whether parallel tool calls (Claude Code sometimes emits multiple in-flight tool calls) round-trip correctly, and whether streaming tool-argument fragments (mid-stream JSON-argument assembly) always reconstruct properly. Exploration flagged these as untested by the proxy's own test suite.

**How to close it:** add a V6 that issues a prompt specifically designed to trigger parallel tool calls (e.g., "read these 3 files simultaneously"). If V6 fails, patch `providers/common/sse_builder.py` where the tool-arg buffer logic lives.

## Machine-level prerequisites aren't automated

**What's known:** `bootstrap.sh` handles user-level install end-to-end (V5 verified).

**What's unknown:** the machine-level prereqs — enabling WSL, setting default version to 1, fixing the Tailscale DNS pin, installing the `apt-mark hold` for systemd — are still manual steps in `PLAN.md`. A true "clean machine" recovery isn't one command.

**How to close it:** write a Windows PowerShell counterpart to bootstrap.sh (`bootstrap.ps1`) that does DISM + WSL install + DNS fix + launches the Linux bootstrap. V5 would then test end-to-end-from-nothing instead of only user-level.

## Token usage granularity

**What's known:** the `usage_logger` middleware records count + status + time-to-first-byte per /v1/messages request. `claude-nim-usage` reports request-count totals.

**What's unknown:** actual prompt and completion token counts per request. Which NIM model (glm4.7 vs kimi-k2-thinking vs step-3.5-flash) is being hit. How close we're running to any NVIDIA-side quota.

**How to close it:** medium-version middleware hook in `providers/openai_compat.py` streaming finalizer to capture `usage: {prompt_tokens, completion_tokens}` from the NVIDIA response. ~45 min of real work — deliberately deferred until a real need surfaces.

## No cost confirmation

**What's known:** NVIDIA NIM's free tier is documented as free up to 40 req/min.

**What's unknown:** whether the account has ever been charged, or is getting close to some internal NVIDIA ceiling that we'd only discover by hitting it.

**How to close it:** add a daily `nim-quota-check` script that queries NVIDIA's usage endpoint and emails/logs remaining budget. Currently the authoritative source is `build.nvidia.com/settings/usage` — manual check.

---

These are **tracked, not forgotten.** None of them block current use. All become worth addressing when the corresponding symptom actually shows up.

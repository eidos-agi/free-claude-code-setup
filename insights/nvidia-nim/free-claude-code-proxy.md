# NVIDIA NIM free-tier Claude Code routing

**Symptom / goal:** Want to run Claude Code without burning paid Anthropic credits — use NVIDIA NIM's free tier (40 req/min, open-weight models like GLM 4.7 / Kimi K2 / Step 3.5) as the backend.

**Context:** NVIDIA offers a free API tier at `build.nvidia.com` with a generous rate limit (40 req/min, no token cap, no card required) that serves third-party open-weight models. Anthropic's Claude Code CLI speaks Anthropic's Messages API format. A translating proxy bridges the two.

**Cause / design:** The proxy receives Anthropic-format requests from Claude Code, converts them to NIM's format, forwards to NIM, converts the response back. Claude Code thinks it's talking to Anthropic; NIM serves an open-weight model whose identity gets overridden by Claude Code's system prompt (the model reports itself as "Claude Sonnet 4.6" or whatever is requested).

**Fix / setup:**
1. Get a NIM API key at `build.nvidia.com/settings/api-keys` (free, no card)
2. Clone [Alishahryar1/free-claude-code](https://github.com/Alishahryar1/free-claude-code) — the translating proxy
3. Configure `.env` with your NIM key and NIM model IDs (e.g. `MODEL_OPUS="nvidia_nim/z-ai/glm4.7"`)
4. `uv sync` to install Python deps; `uv run uvicorn server:app --host 0.0.0.0 --port 8082` to start
5. Launch Claude Code with:
   ```
   ANTHROPIC_BASE_URL=http://localhost:8082
   ANTHROPIC_AUTH_TOKEN=freecc                  # whatever you set in .env
   ANTHROPIC_API_KEY=""                         # NECESSARY — see anthropic-api-key-precedence.md
   USERPROFILE=<isolated-profile>               # NECESSARY — see userprofile-oauth-isolation.md
   claude ...
   ```

**Gotchas:**
- Both auth pitfalls in this insights repo must be neutralized (`ANTHROPIC_API_KEY=""` + isolated USERPROFILE/HOME), or Claude Code silently routes to real Anthropic anyway. The model's convincing Claude impersonation makes the bypass hard to detect without checking proxy logs.
- 40 req/min is a hard ceiling. Each Claude Code tool call = one request. Heavy agent loops (`/ultrareview`, parallel subagents) will hit 429s and backoff.
- Open-weight models have weaker tool-calling fidelity and shorter effective context windows than real Claude. Fine for interactive coding, wrong choice for heavy agentic work.

**Project-specific setup using this approach:** [`/root/repos/free-claude-code-setup/`](file:///root/repos/free-claude-code-setup/) — full ops manual at `PLAN.md` there, including launchers and a `check-nim` health probe.

**Sources:**
- [Alishahryar1/free-claude-code](https://github.com/Alishahryar1/free-claude-code) — the proxy
- [NVIDIA NIM Claude Code integration docs](https://docs.nvidia.com/nim/large-language-models/latest/ai-assistant-integrations/claude-code.html)
- [build.nvidia.com](https://build.nvidia.com)

**Learned:** 2026-04-23 — built the setup on a Shadow PC (WSL1-only). The initial "it works" was deceptive — responses were convincing, but proxy logs showed zero traffic, meaning real Anthropic was being hit. Two layers of auth bypass had to be closed before the proxy was actually in the path.

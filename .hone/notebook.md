# Hone notebook — free-claude-code-setup

Accumulated learnings, newest at top.

## 2026-04-25T203509Z — improved
Tick 1 of free-claude-code-setup. Observed that the live dashboard (mac/bin/claude-nim-dashboard) tracks tokens but never surfaces what those tokens would have cost on Anthropic — i.e. the emotional payoff of the whole proxy was missing. TASK-0004 (savings card) is the High-priority ticket addressing this. Implemented the BACKEND half: Anthropic public list pricing constants per tier, a tier-mapping helper, a counterfactual-cost helper, and two new fields in the snapshot JSON (saved_today_usd, saved_all_usd). Restarted the dashboard. /api/usage now returns saved_today_usd=$7.94 across 288 requests today (9.16M input + 51K output tokens). Backend is the foundation; UI card lands in tick 2.

Full turn: [`turns/2026-04-25T203509Z.md`](turns/2026-04-25T203509Z.md)

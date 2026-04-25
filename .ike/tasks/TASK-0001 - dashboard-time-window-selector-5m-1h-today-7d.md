---
id: TASK-0001
title: 'Dashboard: time-window selector (5m / 1h / today / 7d)'
status: To Do
created: '2026-04-25'
priority: High
tags:
  - dashboard
  - ux
acceptance-criteria:
  - 5 pills (5m / 1h / today / 7d / all) above the grid
  - Active pill visually distinct
  - Selection persists across reloads via localStorage
  - Stream + one-shot endpoints both honor the window
  - Numbers in cards update immediately on switch (no full reload)
---
Currently the dashboard shows "Today" only. Add a row of pill buttons above the cards: 5m / 1h / today / 7d / all. Selection persists in localStorage. The /api/usage and /api/stream payloads gain a `window` field; client passes it as a query param.

Why: when iterating, you usually want the last 5 minutes — today's totals drown out a single test run. When evaluating cost over a week, you want 7d.

File: mac/bin/claude-nim-dashboard. Both server-side (snapshot() takes a window param) and client-side (button row + state).

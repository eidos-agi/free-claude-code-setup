---
id: TASK-0003
title: 'Dashboard: flash newest row on arrival (SSE liveness signal)'
status: To Do
created: '2026-04-25'
priority: Low
tags:
  - dashboard
  - ux
  - polish
acceptance-criteria:
  - New rows in the recent table briefly flash on arrival
  - No flash on initial page load (only on subsequent SSE updates)
  - Animation is CSS-driven (no JS rAF loop)
  - Works correctly when multiple new rows arrive in one tick
---
When a new request lands in the recent table, briefly highlight the new row(s) (background fades from accent color back to default over ~600ms). This is both pretty and useful: it proves the SSE stream is alive and tells you which rows are new vs. just-rendered.

Detect new rows by comparing the snapshot's `recent[0].time` to the previous render's; if changed, animate the new entries.

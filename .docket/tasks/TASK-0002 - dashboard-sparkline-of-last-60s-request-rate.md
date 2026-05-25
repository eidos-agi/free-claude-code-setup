---
id: TASK-0002
title: 'Dashboard: sparkline of last-60s request rate'
status: To Do
created: '2026-04-25'
priority: Medium
tags:
  - dashboard
  - ux
  - viz
acceptance-criteria:
  - 60-second sparkline above the rate bar
  - Updates live with each SSE tick
  - Color matches saturation thresholds (<60% green, <90% yellow, >=90% red)
  - Doesn't reflow the page when bars grow
---
The "Rate · last 60s" card shows a single number + bar. Add a 60-pixel-wide sparkline (one bar per second, last 60s) above the bar so you can see WHEN the requests landed — was it a spike or a steady stream?

Implementation: client keeps a rolling 60-element array of (timestamp, count) buckets; on each SSE snapshot, increment the current second's bucket. SVG path, recolor based on saturation (green/yellow/red same scale as the main bar).

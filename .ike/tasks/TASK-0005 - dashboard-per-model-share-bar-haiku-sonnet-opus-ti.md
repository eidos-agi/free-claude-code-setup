---
id: TASK-0005
title: 'Dashboard: per-model share bar (haiku / sonnet / opus tier breakdown)'
status: To Do
created: '2026-04-25'
priority: Medium
tags:
  - dashboard
  - ux
  - viz
acceptance-criteria:
  - Stacked horizontal bar replacing the text list
  - Three colors clearly distinguishing haiku/sonnet/opus tiers
  - Hover tooltip shows served NIM model name + raw request count
  - Sums to 100% of today's requests
---
The "Today · models" card lists models textually. Replace with a horizontal stacked bar showing the % share of haiku-tier vs sonnet-tier vs opus-tier requests. Each segment labeled with served model name + count.

Why: tells you at a glance whether you're abusing Opus (slow, big context) when Haiku would do, or vice versa. Useful while balancing model picks under the throttle.

Bucket by Anthropic family in the request (claude-opus-* / -sonnet-* / -haiku-* / -3-* etc.) since that's what controls routing.

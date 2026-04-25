---
id: TASK-0004
title: 'Dashboard: "you would have paid $X on Anthropic" counterfactual'
status: To Do
created: '2026-04-25'
priority: High
tags:
  - dashboard
  - ux
  - motivating
acceptance-criteria:
  - A 'savings' card visible in the grid
  - Number based on REQUESTED Anthropic model name (not served NIM model)
  - 'Caveat copy: ''estimated, based on Anthropic public list pricing'''
  - Honors the time-window selector (when that lands)
  - Pricing constants live in one obvious place at the top of the python file
---
The whole point of NIM is the "$0 instead of $real" win. Make that visible. Add a card that shows estimated counterfactual cost — what these tokens would have cost on Anthropic if the request had gone direct.

Use Anthropic's published pricing per model tier (Haiku ~$0.80/MTok in, $4/MTok out; Sonnet ~$3/MTok in, $15/MTok out; Opus ~$15/MTok in, $75/MTok out — verify current pricing). Map each request's REQUESTED Anthropic name (we still log it) to the tier, then sum.

Display: big number "$X.XX saved today" plus a smaller "${cumulative} all time" if --all window.

Don't claim it's exact — small "estimated" caveat.

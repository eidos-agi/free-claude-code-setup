# STATUS

Most-recent-first log of validation runs. `run-all.sh` appends a line on each pass.

| Timestamp (UTC)     | Commit   | Result                          | Wall time | Notes |
|---------------------|----------|---------------------------------|-----------|-------|
| 2026-04-24 22:16:48 | 85abde4  | V1-V4 PASS (V5 validated earlier in session) | ~4 min   | All invariants green: tool-use round-trip, zero Anthropic leak, rate-limit survives, recovery works. V5 reproducibility confirmed via fresh `cnimtest` user in 60s. |

---

## How this file gets updated

`new-bin/validations/run-all.sh` appends a new row to the table on each pass. Entries are intentionally terse — if a specific run needs more detail, link to a log file under `new-bin/logs/`.

A line NOT showing up here means `run-all.sh` was either not run, or it failed. Either way the setup's health claim is unverified beyond the date of the last row.

## How to read this

If the most recent row is older than a month → re-run `./new-bin/validations/run-all.sh` before trusting the claim that the setup works. Claude Code, WSL, NIM API, and model availability all drift.

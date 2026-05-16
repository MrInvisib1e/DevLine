# Output Validation Pipeline

Run after every agent response before the orchestrator accepts it.
All checks are zero-LLM-cost (filesystem + git operations).

## 8-Check Pipeline

| # | Check | Command | On Fail |
|---|-------|---------|---------|
| 1 | Format valid | `grep -E "^STATUS:|^VERDICT:" output` | REJECT — retry with format reminder |
| 2 | Paths exist | `for f in FILES_MODIFIED; do [[ -f "$f" ]] \|\| echo "missing: $f"; done` | RETRY — "hallucinated file path: $f" |
| 3 | Scope clean | `git diff --name-only HEAD \| diff - allowlist` | HUMAN_REVIEW — scope violation |
| 4 | Non-empty | `git diff --stat HEAD \| grep -v "0 insertions"` | RETRY — "no changes detected" |
| 5 | No stubs | `grep -rn "TODO\|FIXME\|NotImplemented\|raise NotImplementedError\|throw new Error.*not impl" FILES_MODIFIED` | RETRY (soft, log location) |
| 6 | Static analysis | `tsc --noEmit 2>&1` or `pyflakes FILES_MODIFIED` | RETRY with error text |
| 7 | Tests pass | Run `<test_cmd>` | RETRY with failing test names |
| 8 | Slop score | prose-to-code ratio in output > 5:1 | LOG warning, proceed |

## Routing Decision

```
checks 1-4 fail  → REJECT (hard) → retry with specific failure message
checks 5-7 fail  → RETRY (soft) → retry with specific error + context
check 8 fails    → LOG warning only (don't block)
retry_count >= 3 → STUCK → mark slice stuck, T3 Gate
all pass         → PROCEED
```

## Issue Fingerprinting on Retry

Track fingerprint `<file>:<line>:<category>` hash across retries.

| Delta | Classification | Action |
|-------|---------------|--------|
| No issues | CLEAN | → done |
| Fewer issues than last | PROGRESS | → continue |
| Same issues persist | STALLED | → mark stuck immediately |
| New issues + old persist | REGRESSION | → mark stuck immediately |
| DEFAULT | MIXED | → continue, escalate faster |

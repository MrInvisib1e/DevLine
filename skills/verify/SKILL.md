---
name: devflow-verify
description: Verification gates before completion claims
requires: []
triggers_on_complete: []
---

# Skill: verify

# DevFlow Verify

Run verification before claiming any DevFlow task is done. Evidence before claims. Always.

**Invoked as:** Referenced by other skills before completion claims. Also safe to call directly.

---

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE — because the AI's confidence is not evidence. Run the command and read the output.
```

If you haven't run the verification command in this message, you cannot claim it passes.

---

## Gate Function

What to run before claiming done:

| Claiming... | Must run | Must confirm |
|-------------|----------|-------------|
| Slice done | `df-test <slice-id>` or `test_cmd` from config | Exit 0, all tests pass |
| Fix applied | Test that reproduces the original bug | Bug no longer reproduces |
| Review complete | Re-read full diff after any late changes | Findings still accurate |
| Memory synced | `df-sync` + check `dirty=false` | `last_synced` = HEAD |
| Feature complete | Full test suite via `test_cmd` | Exit 0 |
| Slice JSON updated | Read JSON file back | Fields match claim |

### Verification Gate Table

| Claim Type | Command to Run | Evidence Required | On Failure |
|-----------|---------------|-------------------|-----------|
| "Slice done" | `df-test <slice-id>` or `test_cmd` | All tests pass output | → FAIL, retry |
| "Fix applied" | `<test_cmd>` | Relevant test names appear | → FAIL, retry |
| "Memory synced" | `df-init --scan` | JSON with current SHA | → run df-sync |
| "Feature complete" | `<test_cmd> && <build_cmd>` | Both pass | → T3 Gate |
| "JSON updated" | `jq . <file>` | Valid JSON parses without error | → fix JSON |
| DEFAULT | Run the most relevant test command | See passing output | → T2 Inform failure |

CHECKPOINT: "[DevFlow] Verification passed: <claim>"

---

## Guard Rails

1. **Evidence before claims.** Never claim work is complete without fresh verification output. — because the AI's confidence is not evidence.
2. **No T3 gates.** Partial verification failures → T2 Inform with specific failures listed. Continue. See `skills/_shared.md`.
3. **Run the actual commands.** Reading test files is not the same as running tests. Read the output.
4. **Reality check.** All verification passes → done. T1 Silent. Don't add extra checks.

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Tests passed earlier" | Earlier ≠ now. Run again. |
| "Just wrote the fix, it works" | Confidence ≠ evidence. Run test. |
| "df-test is slow" | Slow verification > fast false claim. |
| "JSON is just bookkeeping" | Stale JSON breaks resume. Update it. |
| "Review found nothing, skip re-check" | Re-read diff. Confirm. |
| "Partial failures, ask user" | T2 Inform with failures listed. Continue. |
| "Nothing changed, no need to verify" | If nothing changed — skip is fine. Otherwise run it. |

## Red Flags — STOP

- "Should work", "probably passes", "looks correct"
- Marking slice done without running df-test
- Claiming fix without reproducing original failure
- "Great!", "Done!" before verification
- Trusting agent reports without independent check

**Run the command. Read the output. Then claim the result.**

---

## When to Apply

- Before marking slice `status: "done"`
- Before claiming `/fix` resolved the bug
- Before reporting `/review` verdict
- Before Phase 6 completion
- Before any commit implying success

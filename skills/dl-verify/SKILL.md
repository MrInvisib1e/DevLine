# /dl-verify — Pre-Completion Verification

Run verification commands before claiming any work is done. Evidence before claims.

**Invoked as:** `/dl-verify` (call before any completion claim)

<iron-law>
Load `skills/_shared.md` before proceeding. T1/T2/T3 tiers assumed throughout.
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.
</iron-law>

---

## Gates: 0 (autonomous; failures → T2 Inform with specific output, then continue)

---

## Step 0: PRD Acceptance Criteria (ALWAYS FIRST)

Before running any technical checks, verify the feature actually does what was agreed.

Read the PRD from `plan.md`. For each acceptance criterion:

| Criterion | Met? | Evidence |
|-----------|------|----------|
| [criterion from PRD] | yes/no | [test name / observable behavior / screenshot] |

If any criterion is unmet: HALT. Print exactly: "Verification failed: '[criterion]' is not met. Do not mark this feature complete. Fix the missing criterion first."

— because tests and type checks verify technical correctness, not whether the feature does what was agreed. A feature can pass all tests and fail all acceptance criteria.

CHECKPOINT: "[Devline] dl-verify Step 0 done: PRD acceptance criteria checked"

---

## Process

1. **IDENTIFY:** What command proves this claim?
2. **RUN:** Execute the FULL command fresh (not cached output, not "last time I ran it")
3. **READ:** Full output — check exit code, count failures, read error messages
4. **VERIFY:** Does output confirm the claim?
5. **ONLY THEN:** Make the claim

---

## Verification Table

| Claiming | Must Run | Must Confirm |
|----------|----------|-------------|
| Slice done | `test_cmd` from `.devline/config.json` | All tests pass, exit 0 |
| Fix applied | Anti-regression test from behavior contract | Test passes; verify it would fail without fix |
| Review complete | Re-read the diff | Findings are still accurate vs current state |
| Memory synced | `/dl-sync` | `last_synced == HEAD` in config.json |
| Feature complete | `test_cmd && build_cmd` | Both exit 0 |
| Plan tasks done | Re-read `.devline/plans/.../plan.md` | Each task checkbox ticked |
| JSON updated | `python3 -c "import json; json.load(open('file.json'))"` | Parses without error |

---

## Red Flags — STOP

These thoughts mean you haven't verified yet:

| Thought | Reality |
|---------|---------|
| "Should pass now" | Run the command. |
| "Looks correct" | That's not evidence. Run the command. |
| "Tests were passing earlier" | Earlier ≠ now. Run the command. |
| About to commit without running tests | Run the command first. |
| "Just this once" | No exceptions. Evidence before claims. |
| "I can see the fix is right" | Run the command. |

---

## Examples

```
✅ [Run: npm test] [Output: 34/34 pass, exit 0] → "All tests pass"
❌ "Should pass now" / "Looks correct"

✅ [Run: anti-regression test] [Output: PASS, exit 0] → "Bug fix verified"
❌ "I fixed the logic, it should work"

✅ [Run: dotnet build] [Output: Build succeeded, exit 0] → "Build passes"
❌ "Linter passed" (doesn't verify compilation)

✅ [Re-read plan] [Confirm: all checkboxes ticked] → "All plan tasks done"
❌ "Tests pass, phase complete"
```

---

## After Verification

- If all pass: make your claim. Proceed.
- If any fail: T2 Inform with specific failures. Fix before claiming done.
- Do NOT skip to "done" state when verification fails.

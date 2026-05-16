# /df-fix — Hypothesis-Driven Bug Fixing

Fix bugs using memory-aware hypothesis-driven debugging. Max 3 cycles.

**Invoked as:** `/df-fix <bug description>`

---

## Iron Law

```
NO FIX WITHOUT ROOT CAUSE FIRST.
NO FIX WITHOUT A FAILING TEST FIRST (TDD).
```

---

## Pre-Flight (T1 Silent)

1. Check `.devflow/` exists — if not: HALT — "Run `/df-init` first."
2. Check memory staleness:
   ```bash
   LAST=$(python3 -c "import json; print(json.load(open('.devflow/config.json')).get('last_synced',''))")
   HEAD=$(git rev-parse HEAD)
   ```
   If `LAST != HEAD`: run `/df-sync` first. T2 Inform: "Memory was stale — synced."

---

## Step 1 — Node Inference (T2 Inform)

Parse bug description → infer most likely symbol name.

Run: `df-explain <symbol>`

Returns related symbols + call paths.

Print: "Investigating: `{symbol}` and `{N}` related nodes."

---

## Step 2 — Change Impact (T2 Inform)

Run: `df-explain --impact`

This calls `detect_changes` — maps uncommitted diff (if any) to affected symbols + blast radius.

Print the risk classification.

---

## Step 3 — Context + Hypothesis (T2 Inform)

1. Read `.devflow/memory.md` (architecture + conventions)
2. State hypothesis explicitly BEFORE reading any source code:
   ```
   Hypothesis: `{file}` is failing because `{reason}`
   ```
3. Print file list to read; read them

---

## Behavior Contract (T3 Gate — required before any fix)

After forming hypothesis, write this contract and show it to the user:

```
Given:        [precondition — system state before the action]
When:         [action that triggers the bug]
Currently:    [what happens now — the wrong behavior]
Expected:     [what should happen — correct behavior]
Anti-regression: [name of test that proves fix works AND would fail without it]
```

Wait for user to confirm or correct the contract before proceeding.

---

## Cycle Loop (max 3)

**TDD — write failing test FIRST (Iron Law)**

1. Write test that matches the Anti-regression from behavior contract
2. Run test — MUST fail (if it passes immediately, hypothesis is wrong — stop and revise)
3. Apply fix — ONLY to hypothesis-identified files
4. Run `df-check --typecheck-only` — type errors BLOCK (exit 1 = stop here, fix types first)
5. Run test — if PASS → done
6. If FAIL → revise hypothesis, increment cycle

After 3 failures:

**T3 Gate:** Surface all 3 hypotheses + evidence from each cycle. Ask for direction before continuing.

---

## Scope Fence

```
<scope>
EDIT: Only files identified in hypothesis.
DO NOT: Refactor, fix adjacent issues, add features, change unrelated files.
</scope>
```

---

## Systematic Debugging Techniques

If stuck after 2 cycles:

- **Root cause tracing:** Read the full call stack backward from the error. What hands off to what?
- **Defense in depth:** Add validation/assertions at each layer boundary to isolate exactly where the invariant breaks
- **Condition-based waiting:** If the bug is timing-related, replace `sleep N` with polling until a condition is true

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "I'll write the test after" | Test first proves the fix. Skip it = no proof. |
| "The fix is obvious" | State the hypothesis anyway. Review it in 3 minutes. |
| "While I'm in here, also fix X" | Out of scope. Works. Leave it. |
| "Test passes without fix" | Wrong hypothesis. Go back to Step 3. |
| "3 cycles, close enough" | T3 Gate required. Surface evidence, ask for direction. |

---

## After Fix

T2 Inform: "Fix applied. Run `/df-verify` to confirm before claiming done."

---

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | `.devflow/` missing | HALT — "Run `/df-init` first" |
| E02 | df-explain fails | T2 Inform: "Graph query failed — proceeding with limited context" |
| E03 | Test passes immediately on first run | T2 Inform: "Wrong hypothesis — test passes without fix. Revise hypothesis." |
| E04 | 3 cycles exhausted | T3 Gate — surface all hypotheses, ask for direction |

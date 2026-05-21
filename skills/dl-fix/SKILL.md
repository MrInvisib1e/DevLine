---
name: devline-fix
description: Hypothesis-driven bug fixing with 4-phase investigation
requires: [dl-sync]
triggers_on_complete: [dl-verify]
---

# /dl-fix — 4-Phase Hypothesis-Driven Bug Fixing

Fix bugs using memory-aware, structured investigation. Max 3 cycles per phase.

**Invoked as:** `/dl-fix <bug description>`

<iron-law>
Load `skills/_shared.md` before proceeding. It defines T1/T2/T3 tiers, SIF rules, and the Unified Status Model. All tier references in this file assume those definitions are in context.
</iron-law>

---

## Iron Law

<iron-law>
NO FIX WITHOUT ROOT CAUSE FIRST.
NO FIX WITHOUT A FAILING TEST FIRST (TDD).
</iron-law>

---

## Pre-Flight (T1 Silent)

1. Check `.devline/` exists — if not: HALT — "Run `/dl-init` first."
2. Check memory staleness:
   ```bash
   LAST=$(python3 -c "import json; print(json.load(open('.devline/config.json')).get('last_synced',''))")
   HEAD=$(git rev-parse HEAD)
   ```
   If `LAST != HEAD`: run `/dl-sync` first. T2 Inform: "Memory was stale — synced."

---

## Phase 1 — Root Cause Investigation (T2 Inform)

### Step 1.1 — Node Inference

Parse bug description → infer most likely symbol name.

Run: `dl-explain <symbol>`

Returns related symbols + call paths.

Print: "Investigating: `{symbol}` and `{N}` related nodes."

### Step 1.2 — Change Impact

Run: `dl-explain --impact`

Maps uncommitted diff to affected symbols + blast radius.

Print the risk classification.

### Step 1.3 — Evidence Gathering

1. Read `.devline/memory.md` (architecture + conventions)
2. Read error messages carefully — they often contain the exact solution
3. Reproduce the bug consistently — exact steps, every time
4. Check recent changes: `git log --oneline -10`, `git diff`
5. For multi-component systems, trace data at each boundary:

| Boundary | Check |
|----------|-------|
| Entry point | What data enters? |
| Each layer | What data exits? |
| Config/env | Does it propagate correctly? |
| State | Is it consistent at each layer? |
| DEFAULT | Log input/output at the boundary |

CHECKPOINT: "[Devline] Phase 1 complete: evidence gathered"

---

## Phase 2 — Pattern Analysis (T2 Inform)

1. Find working examples in the codebase that do similar things
2. Compare against references — read them COMPLETELY, not just the first few lines
3. List every difference between working code and broken code
4. Understand dependencies: what config, environment, or assumptions does the working code rely on?

| Finding | Action |
|---------|--------|
| Working example found | List differences with broken code |
| No working example | Check external docs, memory.md patterns |
| Pattern mismatch found | This is likely the root cause — proceed to Phase 3 |
| DEFAULT | Document what you found, proceed to Phase 3 |

CHECKPOINT: "[Devline] Phase 2 complete: patterns analyzed"

---

## Phase 3 — Hypothesis & Testing (T2 Inform)

### Step 3.1 — Form Hypothesis

State hypothesis explicitly BEFORE reading source code:
```
Hypothesis: `{file}` is failing because `{reason}`
Evidence: `{what supports this}`
```

### Step 3.2 — Behavior Contract (T3 Gate)

Write this contract and show it to the user:

```
Given:           [precondition — system state before the action]
When:            [action that triggers the bug]
Currently:       [what happens now — the wrong behavior]
Expected:        [what should happen — correct behavior]
Anti-regression: [name of test that proves fix works AND would fail without it]
Root cause:      [the specific code/config/state that causes the bug]
```

Wait for user to confirm or correct the contract before proceeding.

### Step 3.3 — Test Hypothesis Minimally

Test ONE variable at a time. If it doesn't work: form a NEW hypothesis. Do not stack fixes.

---

## Phase 4 — Implementation (TDD Cycle, max 3)

<scope>
EDIT: Only files identified in hypothesis.
DO NOT: Refactor, fix adjacent issues, add features, change unrelated files.
</scope>

### Cycle Loop

1. Write test that matches the Anti-regression from behavior contract
2. Run test — MUST fail (if it passes immediately: wrong hypothesis — return to Phase 1)
3. Apply fix — ONLY to hypothesis-identified files
4. Run `dl-check --typecheck-only` — type errors BLOCK (exit 1 = stop, fix types first)
5. Run test — if PASS → done
6. If FAIL → revise hypothesis, increment cycle

### After 3 Failures — Phase 4.5: Architectural Escalation

<iron-law>
After 3 failed fix attempts, STOP fixing and question the architecture.
</iron-law>

Signs of architectural problem:
- Each fix reveals a new problem in a different place
- Fixes require massive refactoring
- Each fix creates new symptoms

**T3 Gate:** Surface all 3 hypotheses + evidence from each cycle. Present:

```
[Devline] 3 fix attempts exhausted. Pattern suggests architectural issue.

Hypotheses tried:
1. {hypothesis 1} — {result}
2. {hypothesis 2} — {result}
3. {hypothesis 3} — {result}
```

```dl:choice
question: 3 fix attempts exhausted. How do you want to proceed?
options:
  - label: Escalate to /dl-feature
    description: Redesign the affected area — treat this as a new feature
  - label: Provide new direction
    description: You have a hypothesis or idea to try
  - label: Abort fix
    description: Stop here and leave the code as-is
```

---

## Bail-to-Spec

If at ANY point during investigation the fix reveals:
- The bug is actually a missing feature
- The fix requires changes to 5+ files across multiple domains
- The root cause is a design flaw, not a code bug

**T2 Inform:** "This bug is too complex for `/dl-fix`. Escalating to `/dl-feature`."

Automatically transition to `/dl-feature` with the behavior contract as the PRD seed.

---

## Systematic Debugging Techniques

If stuck after 2 cycles:

- **Root cause tracing:** Trace backward through the call chain. Where does the bad value originate? What called this with the bad value? Keep tracing up until the source is found. Fix at the source, not at the symptom.
- **Defense in depth:** Add validation/assertions at each layer boundary to isolate exactly where the invariant breaks.
- **Condition-based waiting:** If the bug is timing-related, replace `sleep N` with polling until a condition is true.

---

## After Fix

T2 Inform: "Fix applied. Run `/dl-verify` to confirm before claiming done."

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "I'll write the test after" | Test first proves the fix. Skip it = no proof. |
| "The fix is obvious" | State the hypothesis anyway. Review it in 3 minutes. |
| "While I'm in here, also fix X" | Out of scope. Works. Leave it. |
| "Test passes without fix" | Wrong hypothesis. Go back to Phase 1. |
| "3 cycles, close enough" | Architectural escalation required. Surface evidence. |
| "Just try changing X and see" | Form a hypothesis first. One variable at a time. |
| "I don't fully understand but this might work" | STOP. Understand before fixing. |
| "One more fix attempt" (when already tried 3) | Architectural escalation. No exceptions. |
| "Quick fix for now, investigate later" | Root cause first. Always. |
| "This is too complex for /dl-fix" | Good — bail to /dl-feature. That's the process. |

## Red Flags — STOP

- Applying a fix without stating a hypothesis
- Stacking multiple fixes without testing between them
- "It's probably X" without evidence
- Fixing where the error appears instead of where it originates
- 3rd fix attempt without escalation
- Modifying files not in the hypothesis scope
- Skipping the behavior contract

**Stop. Re-read the Iron Law. Follow the 4 phases.**

---

## Error Reference

| Code | What happened | Why | How to fix |
|------|--------------|-----|------------|
| E01 | `.devline/` directory is missing | `dl-init` has not been run in this project | HALT. Print exactly: "Run `/dl-init` first to initialize Devline." |
| E02 | `dl-explain` exited with a non-zero code | Graph query failed — symbol not found or graph not built | T2 Inform: "[Devline] Graph query failed — proceeding with limited context." Continue with manual file inspection. |
| E03 | Test passes on first run before any fix is applied | The hypothesis is wrong — the test does not actually cover the bug | T2 Inform: "[Devline] Wrong hypothesis — test passes without fix. Return to Phase 1 and form a new hypothesis." |
| E04 | 3 fix cycles exhausted with no passing result | The issue is likely architectural, not a local code bug | T3 Gate — run architectural escalation (Phase 4.5). Present all 3 hypotheses + evidence. |
| E05 | Fix investigation reveals a missing feature, not a bug | The expected behavior was never implemented | T2 Inform: "[Devline] This is a missing feature, not a bug. Escalating to `/dl-feature`." Transition with behavior contract as PRD seed. |
| E06 | Fix requires changes to 5+ files across multiple domains | Root cause is a design flaw, not a local bug | T2 Inform: "[Devline] Fix scope exceeds `/dl-fix` boundary. Escalating to `/dl-feature`." Transition with behavior contract as PRD seed. |

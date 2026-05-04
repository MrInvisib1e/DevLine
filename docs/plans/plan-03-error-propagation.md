# Plan 3: Error Propagation & Feature Flow Resilience

**Status:** Ready  
**Depends on:** Plan 2 (unified status model in SIF format)  
**Estimated tasks:** 7  
**Execute after:** Plans 6, 1, 2

## Context

The feature flow has 7 verified bugs that cause silent failures: state is never written (making resume broken), DONE_WITH_CONCERNS is ambiguously defined, there is no post-completion verification, and the completion flow depends on an external Superpowers skill. This plan fixes all 7 bugs. Net token impact: -10 tokens (token-neutral, significantly more precise behavior).

## Verified Bugs Being Fixed

| # | Bug | Severity |
|---|-----|----------|
| 1 | `steps[].done` never written by Phase 3 — resume checks it but it's never set | HIGH |
| 2 | Phase 3 doesn't write batch/phase progress to `plan.md` | MEDIUM |
| 3 | 4 different status vocabularies across agents | MEDIUM |
| 4 | `DONE_WITH_CONCERNS` "if correctness-blocking" is undefined | MEDIUM |
| 5 | No post-completion verification (test/build/lint) | HIGH |
| 6 | `finishing-a-development-branch` is external Superpowers dependency | MEDIUM |
| 7 | Phase 4 is thin (27 lines), no contract validation | MEDIUM |

## What's NOT Being Changed

- Phase 5 feedback loop — already routes CHANGES_REQUESTED back to Phase 3 (max 2 cycles). Keep as-is.
- Phase 3 retry loop — max 3 cycles with Prior Work context injection. Keep as-is.
- Stuck slice handling — blocks dependents, not independents. Keep as-is.

## Pre-flight

- [ ] Plans 6, 1, 2 complete
- [ ] No uncommitted changes in `skills/feature/`
- [ ] Record current line count of phase files:
  ```bash
  wc -l skills/feature/phases/phase-3-execution.md
  wc -l skills/feature/phases/phase-4-integration.md
  wc -l skills/feature/phases/phase-6-completion.md
  wc -l skills/feature/phases/resume.md
  ```

## Tasks

### Task 3.1 — Fix state tracking (Bug #1, #2)

**File(s):**
- Modify: `skills/feature/phases/phase-3-execution.md`

**What:**
Add explicit write instructions after every slice verdict. This is the same change as Plan 2 Task 2.6 — if Plan 2 was completed first, this task verifies and extends it.

After each slice agent completes, the orchestrator MUST:

1. **Write slice JSON state:**
   ```bash
   # File: .devflow/plans/<plan-slug>/<slice-id>.json
   # Add after verdict received:
   jq --argjson done true '.steps[N].done = $done' slice.json > tmp && mv tmp slice.json
   # Where N = index of the completed step
   ```

2. **Write progress to plan.md:**
   ```markdown
   <!-- Append to .devflow/plans/<plan-slug>/plan.md after each batch -->
   ## Progress

   | Slice | Status | Verdict | Timestamp |
   |-------|--------|---------|-----------|
   | <slice-id> | done/stuck | PASS/FAIL/BLOCKED | <timestamp> |
   ```

3. **Update batch status:**
   After each batch completes, append to plan.md:
   ```
   ## Batch <N> Complete
   Passed: <list>
   Failed: <list>
   Stuck: <list>
   ```

**Why:** Resume logic (resume.md) reads `steps[].done` to find where to restart. If this field is never written, resume always restarts from scratch.

**Verify:**
```bash
grep "steps\[N\].done\|\.done = true" skills/feature/phases/phase-3-execution.md
grep "Append to.*plan.md\|Write progress" skills/feature/phases/phase-3-execution.md
```

---

### Task 3.2 — Unified status model (Bug #3, #4)

**File(s):**
- Modify: `skills/feature/phases/phase-3-execution.md`
- Modify: `skills/feature/agents/implementation.md`
- Modify: `skills/feature/agents/test.md`
- Modify: `skills/feature/agents/slice-review.md`
- Modify: `skills/feature/agents/integration-test.md`
- Modify: `skills/feature/agents/final-review.md`

**What:**
Replace 4 different verdict systems with 2 clean models:

**Model 1 — Executors** (`implementation.md`, `test.md`):
- Old: `DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED`
- New: `DONE | BLOCKED`

`NEEDS_CONTEXT` → fold into `BLOCKED` (it is a form of blocking)
`DONE_WITH_CONCERNS` → eliminated. Concerns are T2 Inform messages in agent output. Reviewer decides.

**Model 2 — Reviewers** (`slice-review.md`, `integration-test.md`, `final-review.md`):
- Old: `PASS | FAIL` (slice-review), `APPROVED | CHANGES_REQUESTED` (final-review)
- New: `PASS | FAIL` everywhere

Update each agent template's output contract section:

`implementation.md` — replace output section with:
```markdown
## Output Contract

```
STATUS: DONE | BLOCKED
REASON: <one sentence if BLOCKED>
FILES_CHANGED: <comma-separated list>
CONCERNS: <optional: T2 level notes the reviewer should check>
SUMMARY: <one sentence>
```
```

`slice-review.md` — replace output section with:
```markdown
## Output Contract

```
VERDICT: PASS | FAIL
FINDINGS:
  - [CRITICAL] file:line — description
  - [HIGH] file:line — description
  - [MEDIUM] file:line — description
REQUIRED_CHANGES: <only if FAIL — concrete instructions>
```

PASS criteria: 0 CRITICAL findings AND fewer than 2 HIGH findings.
FAIL criteria: any CRITICAL finding OR 2+ HIGH findings.
```

`final-review.md` — replace `APPROVED | CHANGES_REQUESTED` with `PASS | FAIL`.

Add orchestrator decision table to `phase-3-execution.md` (from Plan 2 Task 2.6 if not yet added):
```markdown
## Orchestrator Decision Table

| Executor Result | Tests Pass? | Action |
|----------------|------------|--------|
| DONE | yes | → send to slice-review agent |
| DONE | no | → FAIL, retry (max 3) |
| BLOCKED | — | → log in plan.md, continue with next independent slice |
| PASS (reviewer) | — | → mark slice complete, update state |
| FAIL (reviewer) | — | → retry with findings injected (max 3) |
| 3 retries exhausted | — | → mark stuck, T3 gate |
| DEFAULT | — | → T2 Inform, retry once |
```

**Why:** 4 different vocabularies require the orchestrator to maintain a translation table. Two clean models (DONE/BLOCKED for executors, PASS/FAIL for reviewers) eliminate all translation overhead and remove the undefined "correctness-blocking" ambiguity.

**Verify:**
```bash
grep "DONE_WITH_CONCERNS\|NEEDS_CONTEXT\|APPROVED\|CHANGES_REQUESTED" \
  skills/feature/agents/implementation.md skills/feature/agents/slice-review.md \
  skills/feature/agents/final-review.md skills/feature/phases/phase-3-execution.md
# Expected: 0 matches
grep "DONE\|BLOCKED" skills/feature/agents/implementation.md
grep "PASS\|FAIL" skills/feature/agents/slice-review.md
```

---

### Task 3.3 — Post-completion verification gate (Bug #5)

**File(s):**
- Modify: `skills/feature/phases/phase-6-completion.md`

**What:**
Add a verification gate as the first step of Phase 6 before any completion/cleanup actions.

Prepend to Phase 6 steps:

```markdown
### Step 1 — Post-completion verification [T1/T3]

Run commands from `.devflow/config.json`:

```bash
test_cmd=$(jq -r '.stack.test_cmd // ""' .devflow/config.json)
build_cmd=$(jq -r '.stack.build_cmd // ""' .devflow/config.json)
lint_cmd=$(jq -r '.stack.lint_cmd // ""' .devflow/config.json)
```

| Check | Command | Pass | Fail |
|-------|---------|------|------|
| Tests | `$test_cmd` (if set) | → continue | → route back to Phase 3 |
| Build | `$build_cmd` (if set) | → continue | → route back to Phase 3 |
| Lint | `$lint_cmd` (if set) | → continue | → T2 Inform, proceed |
| Any check fails 3rd time | — | — | → T3 Gate: surface failures |

CHECKPOINT: "[DevFlow] Phase 6 verification: tests=<pass/fail>, build=<pass/fail>."

If tests or build fail: route back to Phase 3 with the failure output as context. Mark the affected slices as needing re-work. Do NOT proceed to completion.
```

**Why:** The feature flow currently completes without running a final test/build. This allows broken code to reach the completion step. A post-completion verification gate catches regressions introduced during integration before they're merged.

**Verify:**
```bash
grep "Step 1.*verification\|Post-completion" skills/feature/phases/phase-6-completion.md
grep "test_cmd\|build_cmd\|lint_cmd" skills/feature/phases/phase-6-completion.md
grep "CHECKPOINT:" skills/feature/phases/phase-6-completion.md
```

---

### Task 3.4 — Inline completion logic (Bug #6)

**File(s):**
- Modify: `skills/feature/phases/phase-6-completion.md`

**What:**
Replace the `finishing-a-development-branch` Superpowers reference with DevFlow's own inline completion flow.

Current (external dependency):
```
Invoke the finishing-a-development-branch skill.
```

Replace with inline steps:

```markdown
### Step 2 — Sync and archive

1. Run `df-sync` — update memory with feature changes
2. Archive plan:
   ```bash
   mv .devflow/plans/<plan-slug>/ .devflow/plans/archive/<plan-slug>-<timestamp>/
   ```
3. Remove active symlink reference to this feature

CHECKPOINT: "[DevFlow] Phase 6: memory synced, plan archived."

### Step 3 — Completion strategy [T3 Gate]

Present options:

```
Feature "<name>" is complete and verified.

How would you like to finish?

A) Merge to <base-branch> now (fast-forward or merge commit)
B) Open pull request (push branch, gh pr create)
C) Keep branch as-is (you'll merge manually)

Enter A, B, or C:
```

### Step 4 — Execute chosen strategy

| Choice | Action |
|--------|--------|
| A (merge) | `git checkout <base> && git merge <feature-branch>` |
| B (PR) | `git push -u origin <feature-branch> && gh pr create --title "<feature>" --draft` |
| C (keep) | T2 Inform: `[DevFlow] Branch kept as <name>. Memory updated.` |

Record completion in `.devflow/history.json`:
```json
{
  "feature": "<name>",
  "completed_at": "<timestamp>",
  "strategy": "<A|B|C>",
  "base_branch": "<branch>"
}
```

CHECKPOINT: "[DevFlow] Phase 6: complete. Strategy: <A|B|C>."
```

**Why:** `finishing-a-development-branch` is a Superpowers skill not available in standalone mode. Inlining it removes the external dependency while providing equivalent functionality. The 3-option menu covers the most common workflows.

**Verify:**
```bash
grep "finishing-a-development-branch\|Superpowers" skills/feature/phases/phase-6-completion.md
# Expected: 0
grep "strategy\|history.json\|gh pr create" skills/feature/phases/phase-6-completion.md
grep "CHECKPOINT:" skills/feature/phases/phase-6-completion.md  # ≥ 3 matches
```

---

### Task 3.5 — Phase 4 contract manifest (Bug #7)

**File(s):**
- Modify: `skills/feature/phases/phase-4-integration.md`

**What:**
Expand Phase 4 from 27 lines to a proper contract validation flow.

New Phase 4 structure:

```markdown
## Phase 4 — Integration Testing

### Step 1 — Build contract manifest [T1]

Before dispatching the integration agent, extract cross-slice interaction points:

For each completed slice, collect:
- **Exports:** functions/classes exported from slice output files
- **Imports:** imports referencing other slice output files
- **Assumptions:** comments in slice output marked `// DF-ASSUMPTION: <text>`

Build cross-reference table:
```
| Slice A exports | Slice B imports A? | Match? |
|-----------------|-------------------|--------|
| UserService.create() | ✓ | yes |
| UserService.getById() | ✗ | — |
```

CHECKPOINT: "[DevFlow] Phase 4: contract manifest built. N interaction points."

### Step 2 — Static contract validation [T1]

Before running integration agent (zero LLM cost):
- Check: every import referencing another slice resolves to an actual export
- Check: no circular dependencies between slices

| Validation | Result | Action |
|------------|--------|--------|
| All imports resolve | PASS | → proceed to Step 3 |
| Unresolved import found | FAIL | → route to responsible slice for fix |
| Circular dependency | FAIL | → T3 Gate: present to developer |

CHECKPOINT: "[DevFlow] Phase 4: static validation <PASS/FAIL>."

### Step 3 — Dispatch integration agent

Dispatch `agents/integration-test.md` with:
- The contract manifest from Step 1
- All slice output files
- The original integration test specifications

Agent returns: `PASS | FAIL`

If FAIL: `responsible_slices{}` identifies which slice owns each failure → route targeted fix back to that specific slice. Never broadcast "fix everything."

### Step 4 — Route results

| Result | Action |
|--------|--------|
| PASS | → proceed to Phase 5 |
| FAIL | → route to responsible slices (targeted, not broadcast) → retry Phase 4 (max 3) |
| 3 retries exhausted | → T3 Gate |
```

**Why:** The current Phase 4 is 27 lines with no contract validation. Static contract checking (imports vs. exports) catches interface mismatches before running expensive LLM-based integration tests.

**Verify:**
```bash
wc -l skills/feature/phases/phase-4-integration.md  # should be >60 lines
grep "contract manifest\|Static contract" skills/feature/phases/phase-4-integration.md
grep "responsible_slices\|targeted.*not broadcast" skills/feature/phases/phase-4-integration.md
grep "CHECKPOINT:" skills/feature/phases/phase-4-integration.md  # ≥ 2 matches
```

---

### Task 3.6 — Issue fingerprinting for retry loops

**File(s):**
- Modify: `skills/feature/phases/phase-3-execution.md`

**What:**
Add issue fingerprinting to the retry loop. Fingerprint format: `SHA12(file:line:category)`.

After each review cycle, classify the attempt:

```markdown
### Issue Fingerprinting

After each retry cycle, compare current issues against previous cycle:

| Classification | Condition | Action |
|---------------|-----------|--------|
| CLEAN | No issues remain | → proceed immediately |
| PROGRESS | Fewer issues than last cycle | → continue retrying |
| MIXED | Some resolved + some new | → continue, escalate faster |
| STALLED | Same issues persist unchanged | → mark stuck immediately (don't waste remaining retries) |
| REGRESSION | New issues appeared + old persist | → mark stuck immediately |

**Exit on STALLED or REGRESSION immediately — do NOT consume remaining retries.**

Fingerprint an issue as: `<file>:<line>:<category>` (not the error message text — message text varies).
Category examples: `type-error`, `missing-import`, `test-failure`, `lint-error`.
```

**Why:** Without fingerprinting, the retry loop can waste 3 cycles on the same unfixable issues. STALLED and REGRESSION exit immediately, preserving retries for cases where progress is actually being made.

**Verify:**
```bash
grep "STALLED\|REGRESSION\|fingerprint" skills/feature/phases/phase-3-execution.md
grep "Exit on STALLED\|mark stuck immediately" skills/feature/phases/phase-3-execution.md
```

---

### Task 3.7 — Fix resume logic

**File(s):**
- Modify: `skills/feature/phases/resume.md`

**What:**
Update resume logic to use the state tracking fields written by Task 3.1.

Current resume logic reads `steps[].done` but this field is never written — so resume always restarts from scratch.

Updated resume steps:

```markdown
### Step 1 — Load plan state [T1]

Read:
- `.devflow/plans/<plan-slug>/plan.md` — check ## Progress section for slice status
- All `<slice-id>.json` files in the plan directory — check `steps[].done`

CHECKPOINT: "[DevFlow] Resume: loaded plan state. Slices: N done, M pending, K stuck."

### Step 2 — Identify resume point

| Condition | Resume From |
|-----------|-------------|
| Slices with `steps[].done = false` AND batch ≠ complete | → continue that batch from those slices |
| All current batch slices done | → move to next batch |
| Phase 3 complete (all batches done) | → check plan.md for Phase 4/5 completion status |
| Phase 4 complete | → resume at Phase 5 |
| Phase 5 complete | → resume at Phase 6 |
| Stuck slices exist | → T3 Gate: show stuck slices, ask direction |
| DEFAULT | → restart from Phase 3, batch 1 |

### Step 3 — Report resume state [T2]

Print: `[DevFlow] Resuming "<feature>" at <phase>/<batch>. N slices remaining.`
Continue with identified resume point.
```

**Why:** Resume currently can't reconstruct state because nothing writes `steps[].done`. With Task 3.1 fixing the writes, this task makes the resume logic actually use those written values.

**Verify:**
```bash
grep "steps\[\].done\|done = false" skills/feature/phases/resume.md
grep "CHECKPOINT:" skills/feature/phases/resume.md
grep "DEFAULT\|resume point" skills/feature/phases/resume.md
```

---

## Verification Gates

After all tasks complete:

- [ ] `steps[].done = true` write instruction exists in phase-3-execution.md
- [ ] Progress append to plan.md instruction exists in phase-3-execution.md
- [ ] `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `APPROVED`, `CHANGES_REQUESTED` absent from all agent files:
  ```bash
  grep -r "DONE_WITH_CONCERNS\|NEEDS_CONTEXT\|APPROVED\|CHANGES_REQUESTED" skills/feature/
  # Expected: 0
  ```
- [ ] Orchestrator decision table exists in phase-3-execution.md
- [ ] Phase 6 Step 1 is post-completion verification
- [ ] Phase 6 no longer references `finishing-a-development-branch` or Superpowers
- [ ] Phase 4 has contract manifest (>60 lines)
- [ ] Issue fingerprinting classification table exists in phase-3-execution.md
- [ ] Resume logic reads `steps[].done` field

## Rollback

```bash
git checkout HEAD -- \
  skills/feature/phases/phase-3-execution.md \
  skills/feature/phases/phase-4-integration.md \
  skills/feature/phases/phase-6-completion.md \
  skills/feature/phases/resume.md \
  skills/feature/agents/implementation.md \
  skills/feature/agents/test.md \
  skills/feature/agents/slice-review.md \
  skills/feature/agents/integration-test.md \
  skills/feature/agents/final-review.md
```

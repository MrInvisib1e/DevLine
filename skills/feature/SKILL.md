# Skill: feature

# DevFlow Feature Skill

Orchestrate a feature from idea to merged code. Drives PRD interrogation, domain analysis, slice planning, parallel agent execution, testing, review, and clean completion.

**Invoked as:** `/feature <description>`, `/feature quick <description>`, or `/feature resume`

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `/feature <description>` | Start a new feature (full mode) |
| `/feature quick <description>` | Start a new feature (quick mode — fewer questions, 1-3 slices) |
| `/feature resume` | Resume an in-progress feature |

---

## Pre-Flight

Run these checks before anything else. Do not proceed if any fail.

**1. df-init check**

```bash
which df-init && ls .devflow/memory/ 2>/dev/null
```

If `.devflow/` does not exist: HALT — "Run `/init` first to initialize DevFlow."

**2. Memory check**

If `.devflow/memory/` is empty or missing: HALT — "Memory is empty. Run `/init` to set up project memory."

**3. Active plan check** (skip if command is `/feature resume`)

```bash
ls -la .devflow/active 2>/dev/null
```

If `.devflow/active` symlink exists: HALT — "A feature is already in progress. Use `/feature resume` to continue, or delete `.devflow/active` to start fresh."

**4. Pre-flight build check**

Read the test command from `.devflow/memory/` (check for `test_cmd` in config or memory files). Run it:

```bash
<test_cmd>
```

- If build fails (compile error): HALT — "Fix build errors before starting a new feature." (error E15)
- If tests fail (runtime failures, not compile): show failures, ask: "Fix these first, or proceed with this baseline? (failures will be tracked)" If proceeding: record failures in `plan.md` under `## Baseline Health`.

---

## Entry Routing

Parse the user's command:

- `/feature resume` → skip to [Phase: /feature resume]
- `/feature quick <description>` → set `QUICK_MODE=true`, go to Phase 0 with description
- `/feature <description>` → set `QUICK_MODE=false`, go to Phase 0 with description
- No description provided → ask: "What feature are you building?"

---

## Phase 0: PRD Interrogation

Goal: turn a feature description into a structured PRD that everyone agrees on before any code is planned.

### Full Mode (QUICK_MODE=false)

Ask these questions **ONE AT A TIME**. Wait for the answer before asking the next.

1. **Actor:** "Who is the primary actor? (e.g., authenticated user, admin, anonymous visitor)"
2. **Goal:** "What does the actor want to accomplish? (one sentence)"
3. **Scope:** "What is explicitly IN scope for this feature?"
4. **Out of scope:** "What is explicitly OUT of scope? (prevents scope creep)"
5. **Success criteria:** "How will we know this feature is done? List 2-4 acceptance criteria."
6. **Edge cases:** "Are there any important edge cases or error states to handle?"

After all answers, present the structured PRD:

```
## PRD: <Feature Name>

**Actor:** <actor>
**Goal:** <goal>
**Scope:** <scope>
**Out of scope:** <out of scope>
**Success criteria:**
- <criterion 1>
- <criterion 2>
...
**Edge cases:** <edge cases>
```

### Quick Mode (QUICK_MODE=true)

Ask only:
1. "Who is the primary actor?"
2. "What are 2-3 key acceptance criteria?"

Generate the PRD from the description + these 2 answers. Present for approval.

### STOPPING GATE — PRD Approval

> **"Does this PRD look right? (yes to proceed, or tell me what to change)"**

**DO NOT proceed to Phase 1 until the user explicitly approves the PRD.**

If the user requests changes: revise the PRD and re-present it. Repeat until approved.

---

## Phase 1: Domain Analysis

Goal: understand which codebase areas this feature will touch, and extract patterns for agents to follow.

### Step 1: Load Project Structure

Run:

```bash
df-explain
```

Read the output. Identify which modules, services, and controllers are relevant to the PRD. If `df-explain` fails: retry once; if still failing, proceed with degraded analysis and warn the user (error E13).

### Step 2: Identify Affected Modules

Based on the PRD and `df-explain` output, list:

- **Backend modules:** which services, entities, and controllers will be touched
- **Frontend modules:** which components, routes, and stores will be touched
- **Database:** any new tables or migrations needed
- **Dependencies:** any external services, APIs, or packages needed

### Step 3: Gather Code Patterns

Find a **reference feature** — an existing feature in the codebase that is structurally similar to what we're building.

Ask the user: "I'll use `[feature X]` as the reference for code patterns. Does that work, or is there a better reference?"

**Greenfield fallback (no similar feature):** Use `.devflow/memory/` architecture docs and `CONTRIBUTING.md` if present.

Read up to 5 key files from the reference feature:
- Entity/model
- Service/repository
- Controller/API handler
- Frontend component
- Test file

Extract patterns. They will be written to `plan.md` in Phase 2 under `## Pattern Library`. For now, hold them in session context.

````markdown
## Pattern Library

### Entity Pattern (from Reference/Entity.cs)
```csharp
[paste real code snippet]
```

### Service Pattern (from Reference/Service.cs)
```csharp
[paste real code snippet]
```

### Controller Pattern (from Reference/Controller.cs)
```csharp
[paste real code snippet]
```

### Frontend Pattern (from reference/Component.svelte)
```svelte
[paste real code snippet]
```

### Test Pattern (from tests/reference.spec.ts)
```typescript
[paste real code snippet]
```
````

### Step 4: Capture Domain Analysis (Written to plan.md in Phase 2)

Assemble this section. It will be written to `plan.md` when the plan folder is created in Phase 2.

```markdown
## Domain Analysis

**Affected backend modules:** [list]
**Affected frontend modules:** [list]
**Database changes needed:** [yes/no — describe what]
**Reference feature:** [name + path]
**External dependencies:** [list or "none"]
**Key risks:** [list or "none"]
```

---

## Phase 2: Slice Planning

Goal: decompose the feature into vertical slices, define their dependencies, and get user approval before writing any code.

### What is a Vertical Slice?

A vertical slice is thin, user-visible functionality cutting through ALL required layers:
- **Result:** "[Actor] can [verb] [noun]" — a non-developer could understand it
- **Layers:** touches ≥2 architecture layers (exception: pure migration slices are OK)
- **Independently deployable:** partial feature works after this slice
- **Independently testable:** given declared dependencies are complete

**NOT a vertical slice:**
- Layer-only: "create all entities", "set up all endpoints", "add all components"
- Too thin: single layer ("add Comment entity")
- Too fat: entire feature in one slice ("build comment system")
- Technical-only: refactors or optimizations without user-visible result

**Litmus test:** Can you write a Playwright e2e test a non-developer could read? If not → not a slice.

### Slice Decomposition Process

1. Re-read the PRD acceptance criteria
2. Map each criterion to a user-visible slice (usually 1 criterion = 1 slice)
3. Check: can complex criteria be split into smaller slices? (e.g., "create comment" before "edit comment")
4. Define dependencies: which slices need other slices to be complete first?
5. **Quick mode check (do this BEFORE creating any files):** If QUICK_MODE=true and analysis reveals >3 slices are genuinely needed, warn the user NOW: "This feature may require more than 3 slices — quick mode auto-generates 1-3. Continue with quick mode (auto-slim to 3 most important) or switch to full mode?" Wait for answer before proceeding.

### Slice Sizing Checklist

Before finalizing each slice, verify ALL of these:

- [ ] 3-8 files affected
- [ ] 3-10 implementation steps
- [ ] Slice MD will be 100-300 lines (target), 400 max
- [ ] Touches ≥2 layers (unless migration-only)
- [ ] Can be expressed as "[Actor] can [verb] [noun]"
- [ ] Dependencies explicitly declared (not assumed)
- [ ] File overlap with same-batch slices analyzed for parallel safety

### Parallel Safety Analysis

For each pair of slices in the same potential batch, compare their file lists:

- **Safe (additive):** Both slices ADD to the same file in different locations (e.g., DI registrations, route declarations, barrel exports) → safe to parallelize
- **Unsafe (conflicting):** Both slices MODIFY the same function or method body → must serialize

If conflicting: add an artificial `depends_on` to force serialization. Document reason in `plan.md § Dependency Notes`.

### DAG and Batches

Organize slices into execution batches:

```markdown
## Slice DAG

| Slice | Depends On | Parallel Safe With | Batch |
|-------|------------|-------------------|-------|
| slice-1-create-comment | none | slice-2-list-comments | 1 |
| slice-2-list-comments | none | slice-1-create-comment | 1 |
| slice-3-delete-comment | slice-1 | — | 2 |

## Execution Batches

Batch 1 (parallel): slice-1-create-comment, slice-2-list-comments
Batch 2 (sequential): slice-3-delete-comment
```

### Create Plan Folder and Files

1. Generate a slug from the feature name: `feature-<slug>` (lowercase, hyphens, no special chars)
2. Create plan folder: `.devflow/plans/YYYY-MM-DD-<slug>/`
3. Write `plan.md` with:
   - Feature name and date
   - PRD section (from Phase 0)
   - Domain Analysis section (from Phase 1)
   - Pattern Library section (from Phase 1)
   - Slice DAG
   - Execution Batches
   - Status tracking table (all slices: `pending`)
4. For each slice, create TWO files: `slice-N-<slug>.json` and `slice-N-<slug>.md`
5. Create `.devflow/active` symlink:

Run from the repo root:

```bash
# Run from repo root
ln -sfn "plans/YYYY-MM-DD-<slug>" ".devflow/active"
# The target is relative to the symlink's parent directory (.devflow/)
```

6. Create git branch:

```bash
git checkout -b feature/<feature-slug>
```

#### Slice JSON Schema

```json
{
  "id": 1,
  "name": "<Actor> can <verb> <noun>",
  "instructions": "slice-N-<slug>.md",
  "layers": ["db", "service", "api", "frontend"],
  "result": "<Expected result — what is observable when this slice is done>",
  "test_cmd": "<command to run to verify this slice>",
  "depends_on": [],
  "status": "pending",
  "cycle": 0,
  "max_cycles": 3,
  "steps": [
    { "id": "s1", "action": "create", "file": "path/to/file", "done": false }
  ],
  "test_steps": [
    { "id": "t1", "file": "tests/path/to/test.spec.ts", "done": false }
  ],
  "implementation_summary": null,
  "files_changed": null,
  "test_result": null,
  "test_summary": null,
  "test_agent_skipped": false,
  "test_agent_skip_reason": null,
  "review_findings": null,
  "concerns": null,
  "worktree_path": null
}
```

**Status values:** `pending` | `in_progress` | `done` | `stuck`

#### Slice MD Template

```markdown
# Slice N: <Name>

> **Agent:** You are implementing this slice in isolation. Read this document completely
> before writing any code. Your job is to implement exactly what is described here,
> following the patterns shown, and leave a clean git commit when done.
> Dependencies complete: [slice IDs or "none"]

## Goal

[Actor] can [verb] [noun].

## Context

**Feature:** [Feature name from PRD]
**Slice:** [N of M]
**Dependencies:** [Other slice names that must be complete, or "none"]
**Worktree:** [Path if parallel, or "main branch" if sequential]

[2-3 sentences about where this fits in the feature and what previous slices built, if any.]

## Code Patterns to Follow

[Paste ONLY the layers relevant to this slice from the Pattern Library]

## Steps

### [File: path/to/Entity.cs] (create)

**What:** Create the [Entity] entity with these fields:
- `Id` (int, primary key)
- `Content` (string, required)
- ...

**Anchor:** class `EntityName` in namespace `Project.Entities`

[paste reference pattern or target structure]

### [File: path/to/Service.cs] (modify)

**What:** Add `Create[Entity]Async` method to `[Service]`.

**Anchor:** method `Create[Entity]Async(Create[Entity]Request request, int userId)`

[paste reference pattern]

## Expected Result

Given: [prerequisites — which other slices must be done]
When: [the action]
Then: [the assertion — e.g., "POST /api/comments returns 201 with the new comment body"]

## Files Touched

| File | Action | Layer |
|------|--------|-------|
| path/to/Entity.cs | create | db |
| path/to/Service.cs | modify | service |

## Dependencies

Depends on: [slice IDs or "none"]
```

**Target length:** 100-300 lines. Max 400. Code examples are guidance, not mandates.

### STOPPING GATE — Slice Approval

Present the full slice plan:

```
## Slice Plan

**Feature:** <feature name>
**Total slices:** N
**Execution batches:** M

| # | Name | Layers | Deps | Batch |
|---|------|--------|------|-------|
| 1 | User can create comment | db,service,api,frontend | none | 1 |
| 2 | User can list comments | api,frontend | none | 1 |
| 3 | User can delete comment | service,api,frontend | 1 | 2 |

**Execution order:**
- Batch 1 (parallel): slice-1, slice-2
- Batch 2 (sequential): slice-3
```

> **"Does this slice plan look right? (yes to proceed, or tell me what to change)"**

**DO NOT proceed to Phase 3 until the user explicitly approves the slices.**

**If user requests changes:**
1. Ask: "What would you change?" (open-ended)
2. Adjust: merge/split/reorder/add slices per feedback
3. Regenerate ONLY the affected slice JSON+MD files
4. Re-present ONLY the changed slices
5. Do NOT touch already-approved slices

**Quick mode:** Auto-generate 1-3 slices without full decomposition. Still requires approval gate. (>3 slice warning was already shown during decomposition step 5.)

---

## Phase 3: Slice Execution

Goal: implement all slices, batch by batch, with retry loops.

### Batch Execution Loop

For each batch (in order):

1. Read all slices in this batch from their JSON files (check `depends_on` all satisfied)
2. If batch has >1 slice AND slices are parallel-safe AND QUICK_MODE=false: dispatch concurrently using Task tool
3. If QUICK_MODE=true OR batch has 1 slice OR slices are sequential: dispatch one at a time

**For each slice in the batch:**

#### Step 1: Set Up Worktree (parallel slices only)

For parallel batches (full mode), create an isolated worktree per slice:

```bash
df-workspace create feature/<feature-slug>-slice-N
```

Write the worktree path to `slice-N.json` → `worktree_path` field.

For sequential slices (or quick mode): work directly on the feature branch (no worktree).

#### Step 2: Dispatch Implementation Agent

Combine:
- `skills/feature/agents/implementation.md` — role/contract
- `slice-N-<slug>.md` — mission briefing
- Domain Analysis + Pattern Library sections from `plan.md` — context
- If cycle > 1: Prior Work section (see Retry below)

Dispatch as a subagent. Wait for the Implementation Report.

Update `slice-N.json`:
- `status: "in_progress"`
- `cycle: N`

#### Step 3: Handle Implementation Result

**DONE:** Proceed to Step 4.

**DONE_WITH_CONCERNS:** Read concerns. If correctness-blocking → treat as BLOCKED. Otherwise → proceed to Step 4 and note concerns.

**NEEDS_CONTEXT:** Provide the missing context (check `plan.md`, `df-explain` output). Re-dispatch the same agent.

**BLOCKED:**
- If context problem → provide context, re-dispatch
- If reasoning problem → re-dispatch with more capable model
- If blocker is a dependency on another slice → add dependency to `depends_on`, defer to next batch
- If unresolvable → mark `status: "stuck"`, continue with other slices

Update `slice-N.json`:
- `implementation_summary: "..."`
- `files_changed: [...]`
- `concerns: null | "..."`

#### Step 4: Dispatch Test Agent (unless skip criteria met)

**Skip if ALL of:**
- Quick mode AND ≤2 implementation steps AND test_cmd already passed AND no new user-facing behavior

**Always dispatch if any of:**
- New user-facing behavior (any new UI or API)
- >3 files modified
- No existing e2e coverage for this behavior

If skipping: update `slice-N.json` → `test_agent_skipped: true`, `test_agent_skip_reason: "..."`

If dispatching: combine `agents/test.md` + slice mission + domain test patterns. Wait for Test Agent Report.

Update `slice-N.json`:
- `test_summary: {...}`
- `test_result: "PASS (N/N)" | "FAIL (N/N)"`

#### Step 5: Dispatch Slice Review Agent

Combine:
- `agents/slice-review.md` — role/contract
- `slice-N-<slug>.md` — spec to review against
- All files from `files_changed` — actual implementation
- Test results from Step 4 (or test_cmd result if test agent was skipped)
- Domain Analysis from `plan.md` — architecture context

Wait for Slice Review Report.

**If PASS:** mark `slice-N.json` → `status: "done"`. Proceed to next slice.

**If FAIL:** go to Retry.

#### Retry Loop

Max cycles: `slice-N.json` → `max_cycles` (default 3).

On FAIL:
1. Read `review_findings.required_changes` from the Slice Review Report
2. Increment `cycle` in `slice-N.json`
3. If `cycle > max_cycles`: mark `status: "stuck"`, skip this slice, continue

Retry dispatch — combine:
- `agents/implementation.md` — role
- `slice-N-<slug>.md` — original mission (DO NOT modify)
- Domain context from `plan.md`
- **Prior Work section** (injected at top of mission context):

```
## Prior Work (Cycle N)

**What was implemented:**
[implementation_summary from previous cycle]

**Files changed:**
- path/to/file.cs — [brief description]

**Test result:** PASS (N/N) | FAIL (N/N)

**Review verdict:** FAIL

**Required changes:**
1. [specific fix]
2. [specific fix]

Read the existing files first. Fix ONLY the listed issues. Do NOT re-implement from scratch.
```

After retry, return to Step 3.

#### Merge Parallel Slices (after each parallel batch)

After all slices in a parallel batch complete (done or stuck):

1. For each slice with a worktree:
   ```bash
   # Merge slice branch into feature branch
   git checkout feature/<feature-slug>
   git merge feature/<feature-slug>-slice-N
   ```
2. If merge conflicts: run `df-resolve` and ask user to resolve, then retry merge
3. Clean up worktrees:
   ```bash
   df-workspace remove feature/<feature-slug>-slice-N
   ```

#### Stuck Slice Handling

Stuck slices block their dependents but not independent slices.

After a batch completes with stuck slices, report to user:

```
Slice N ("<name>") is stuck after 3 cycles. Its dependents cannot proceed:
- Slice M ("<name>") — blocked

Other slices not dependent on Slice N will continue.
```

Ask: "Would you like to: (1) manually implement slice N and mark it done, (2) remove it and its dependents from scope, or (3) abort?"

---

## Phase 4: Integration Testing

Goal: verify all slices work together as a complete feature.

Run AFTER all batches complete (even if some slices are stuck — test what's there).

**Quick mode skip:** If feature has only ONE slice: skip Phase 4 (single slice has no cross-slice interactions to test). Record `## Phase 4 Status: SKIPPED` in `plan.md`.

### Step 1: Dispatch Integration Test Agent

Combine:
- `agents/integration-test.md` — role/contract
- All completed slice MDs (from `plan.md` slice list — skip stuck slices)
- Full `plan.md`
- Domain context (test patterns)

Wait for Integration Test Report.

### Step 2: Handle Result

**DONE:** Proceed to Phase 5. Record `## Phase 4 Status: COMPLETE` in `plan.md`.

**DONE_WITH_CONCERNS:** Note concerns. Proceed to Phase 5 but flag concerns in `plan.md`. Record `## Phase 4 Status: COMPLETE_WITH_CONCERNS`.

**BLOCKED or failures:** Report to user. Ask: "Integration tests failing — see report. Fix and re-run integration tests, or proceed to final review anyway?"

Write integration test results to `plan.md` under `## Integration Test Results`.

---

## Phase 5: Final Review

Goal: holistic architecture-aware review of the complete feature.

### Step 1: Dispatch Final Review Agent

Combine:
- `agents/final-review.md` — role/contract
- Full `plan.md` (PRD + domain + all slice statuses + integration results)
- All files changed across all slices (from each slice's `files_changed`)
- `.devflow/memory/` — project architecture context

Wait for Final Review Report.

### Step 2: Handle Result

**APPROVED:** Proceed to Phase 6. Record `## Phase 5 Status: COMPLETE` in `plan.md`.

**CHANGES_REQUESTED:**
- Read required changes
- Determine which slices are affected
- Re-open affected slices: reset `status: "pending"`, create new slice JSON/MD for fix if needed
- Re-run Phase 3 for affected slices only
- Re-run Phase 5 after fixes
- If CHANGES_REQUESTED after >2 cycles: escalate to user — present all findings and ask for direction

Write final review result to `plan.md` under `## Final Review`.

---

## Phase 6: Completion

Goal: sync memory, archive the plan, and hand off to finishing-a-development-branch.

### Step 1: Memory Sync

```bash
df-sync
```

If df-sync fails: warn but continue (don't abort completion).

### Step 2: Archive Plan

Update `plan.md`:
- Add `## Completion` section with timestamp
- Update overall status: `COMPLETE` (or `COMPLETE_WITH_STUCK_SLICES` if any stuck)
- List stuck slices if any (for follow-up)

The plan folder remains as an audit trail. Do NOT delete it.

### Step 3: Remove Active Symlink

```bash
rm .devflow/active
```

This marks the feature as no longer in-progress.

### Step 4: Hand Off

Invoke the `finishing-a-development-branch` skill. This skill handles the merge/PR/cleanup decision — do not make that decision yourself.

Present a summary to the user:

```
## Feature Complete: <Feature Name>

**Slices:** N done, M stuck (if any)
**Tests:** X passing, Y failing (if any)
**Branch:** feature/<feature-slug>

[finishing-a-development-branch will guide you through merge/PR options]
```

---

## /feature resume

### Step 1: Check for Active Plan

```bash
readlink .devflow/active
```

If `.devflow/active` does not exist: error E10 — "No active feature found. Use `/feature <description>` to start one."

If it exists but the target directory is missing: try to find the plan by listing `.devflow/plans/` and ask user which to resume.

### Step 2: Load Plan State

Read `plan.md` — extract:
- Feature name
- PRD
- Domain Analysis
- Execution batches

Read all `slice-N-*.json` files — build status map.

### Step 3: Find Resume Point

Scan batches in order:

1. Any slices `stuck`? → Report them to user before resuming
2. Find the **first batch** that has `pending` or `in_progress` slices
3. For `in_progress` slices: check `steps[].done` — show progress, offer to restart or continue from last done step
4. All slices `done`? → Check `plan.md` for `## Phase 4 Status`:
   - Missing or not COMPLETE → resume at Phase 4
   - COMPLETE → check `## Phase 5 Status`: not COMPLETE → resume at Phase 5
   - Phase 5 COMPLETE → run Phase 6

### Step 4: Show Resume Status

```
## Resuming: <Feature Name>

| Slice | Status | Progress |
|-------|--------|----------|
| 1: User can create comment | ✅ done | — |
| 2: User can list comments | 🔄 in_progress | Step 2/5 done |
| 3: User can delete comment | ⏳ pending | — |

**Resuming at:** Slice 2 (continuing from Step 3)
**Next batch:** Slice 3 (after Slice 2 completes)
```

Confirm with user, then resume Phase 3 at the identified slice.

### Edge Cases

- `.devflow/active` symlink points to non-existent directory: list `.devflow/plans/` and ask user which to resume
- All slices done but no active symlink: plan is archived — can't resume (suggest `/feature <desc>` for new work)
- All slices stuck: report to user and ask for direction

---

## Quick Mode

Triggered by explicit `/feature quick <description>` invocation only. Never auto-activate.

| Phase | Full Mode | Quick Mode |
|-------|-----------|------------|
| Phase 0 | 3–6 clarifying questions | 2–3 questions |
| Phase 1 | Full domain analysis | Same |
| Phase 2 | Full decomposition | Auto-generate 1–3 slices, still requires approval |
| Phase 3 | Parallel dispatch, worktrees | Always sequential, direct commits, no worktrees |
| Test Agent | Always dispatch | Skip if: ≤2 steps + test_cmd passed + modifying existing behavior |
| Phase 4 | Always | Skip if single slice and no stuck slices |
| Phase 5 | Always | Same |

**Quick mode boundary:** If analysis during Phase 2 reveals >3 slices are genuinely needed, warn the user: "This feature may require more than 3 slices — quick mode auto-limits to 3 most important. Continue with quick mode (auto-slim to 3) or switch to full mode?" Wait for answer before proceeding.

---

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | df-init not run — `.devflow/` missing | HALT — "Run `/init` first" |
| E02 | Memory empty — `.devflow/memory/` missing or empty | HALT — "Run df-init to set up project memory" |
| E03 | Active plan exists on fresh `/feature` start | HALT — "Use `/feature resume` or delete `.devflow/active` to abort" |
| E04 | User rejects PRD | Revise and re-present |
| E05 | User rejects slices | Adjust and re-present |
| E06 | Slice stuck (max cycles exceeded) | Mark stuck, continue independent slices, report to user |
| E07 | All slices in batch stuck | Pause, report to user, ask for direction |
| E08 | Worktree creation fails | Report error, ask to retry or use sequential mode |
| E09 | Merge conflict unresolvable | Run df-resolve, escalate to user |
| E10 | `/feature resume` with no active plan | HALT — "No active feature. Use `/feature` to start one" |
| E11 | Final review CHANGES_REQUESTED | Re-open affected slices, re-run; escalate to user after >2 cycles |
| E12 | Slice JSON corrupted or unreadable | Report specific file; ask user to fix or reset slice |
| E13 | df-explain fails | Warn and proceed with degraded analysis |
| E14 | Integration test persistent failure | Report specific failures; ask user to fix or override |
| E15 | Build fails at pre-flight | HALT — "Fix build errors before starting a new feature" |

### Guard Rails

These rules are ABSOLUTE — never override:

1. **Never auto-proceed past a STOPPING GATE.** Always wait for user approval.
2. **Never dispatch two batches simultaneously.**
3. **Never modify slice MD files during execution.** They are the spec.
4. **Always update slice JSON immediately** after each agent completes.
5. **Never skip Phase 6.** Memory sync and cleanup must happen.
6. **Never remove `.devflow/plans/` folders.** They are audit trails.
7. **If unsure about scope:** stop and ask. Don't guess.

### Abort Cleanup Protocol

On any unrecoverable error or user abort:
1. Update `plan.md` status → `ABORTED`
2. Remove `.devflow/active` symlink
3. Clean up worktrees (`df-workspace remove` for each active worktree)
4. Keep plan folder as audit trail
5. Keep `feature/<slug>` branch (for manual recovery)

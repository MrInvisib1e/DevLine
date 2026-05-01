# Feature Skill Design

**Date:** 2026-05-01  
**Status:** Approved  
**Replaces:** Portions of `InitialSpec.md` §8 (Feature Execution Flow)

---

## Overview

The `feature` skill is the core value proposition of DevFlow: a full orchestration loop that takes a natural-language feature description from PRD interrogation through slice planning, parallel subagent execution, testing, review, and clean completion.

It is invoked as:
- `/feature <description>` — full mode (all phases, all gates)
- `/feature quick <description>` — abbreviated mode (fewer questions, no worktrees)
- `/feature resume` — resume a previously interrupted feature

---

## File Structure

```
skills/feature/
  SKILL.md                              ← main session orchestrator
  agents/
    implementation.md                   ← Implementation Agent role + contract
    test.md                             ← Test Agent role + contract
    slice-review.md                     ← Slice Review Agent role + contract
    integration-test.md                 ← Integration Test Agent role + contract
    final-review.md                     ← Final Review Agent role + contract

.devflow/plans/<YYYY-MM-DD>-<slug>/     ← runtime, per feature (created at Phase 2)
  plan.md                               ← PRD, domain analysis, DAG, batches, status
  slice-1-<slug>.json                   ← machine-readable: status, deps, step tracking
  slice-1-<slug>.md                     ← agent mission briefing: instructions, patterns, steps
  slice-2-<slug>.json
  slice-2-<slug>.md
  ...
.devflow/active → plans/<folder>/       ← symlink, exists only during active feature
```

---

## Slice File Design

Each vertical slice is represented by two files that together form the complete slice definition.

### Slice JSON Schema

The JSON file is the machine-readable source of truth for orchestration:

```json
{
  "id": 1,
  "name": "User can create a comment",
  "instructions": "slice-1-create-comment.md",
  "layers": ["db", "service", "api", "frontend"],
  "result": "POST /api/comments returns 201, comment appears in UI",
  "test_cmd": "playwright test --grep 'create comment'",
  "depends_on": [],
  "status": "pending",
  "cycle": 0,
  "max_cycles": 3,
  "steps": [
    { "id": "s1", "action": "create", "file": "Entities/Comment.cs", "done": false },
    { "id": "s2", "action": "modify", "file": "Data/AppDbContext.cs", "target": "AppDbContext", "done": false },
    { "id": "s3", "action": "create", "file": "Services/CommentService.cs", "done": false },
    { "id": "s4", "action": "create", "file": "Controllers/CommentsController.cs", "done": false },
    { "id": "s5", "action": "create", "file": "src/routes/comments/+page.svelte", "done": false }
  ],
  "test_steps": [
    { "id": "t1", "file": "tests/comments.spec.ts", "done": false }
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

**After Implementation Agent completes, orchestrator updates:**
```json
{
  "status": "done",
  "cycle": 1,
  "implementation_summary": "Created Comment entity with EF Core config, CommentService with CRUD, REST endpoint, and Svelte create form.",
  "files_changed": ["Entities/Comment.cs", "Data/AppDbContext.cs", "Services/CommentService.cs", "Controllers/CommentsController.cs", "src/routes/comments/+page.svelte"],
  "test_result": "PASS (3/3)",
  "concerns": null
}
```

**After Slice Review Agent fails, orchestrator updates:**
```json
{
  "review_findings": {
    "verdict": "FAIL",
    "critical": ["CommentService missing transaction wrapper — data loss risk"],
    "important": ["No pagination on GET /api/comments"],
    "minor": ["Inconsistent naming: CreateCommentDto vs CommentCreateDto"],
    "required_changes": [
      "Wrap CreateAsync in DbContext.Database.BeginTransactionAsync()",
      "Add [FromQuery] int page = 1, int pageSize = 20 to GetAll endpoint"
    ]
  }
}
```

### Slice MD Template

The MD file is the agent's mission briefing. It must be stateless — a disconnected agent with no prior context must be able to execute it correctly.

```markdown
# [Slice Name]

> **Agent Instructions:** You are implementing one vertical slice of a feature. Read this document
> completely before writing any code. Your job is to implement exactly what is described here,
> following the patterns shown, and to leave a clean git commit when done.

## Goal

[One sentence: what user-visible result this slice achieves]

## Context

**Feature:** [Feature name from PRD]  
**Slice:** [N of M]  
**Dependencies:** [Other slice names that must be complete before this, or "none"]  
**Worktree:** [Path if parallel, or "main branch" if sequential]

## Code Patterns to Follow

[Verbatim code snippets from similar feature. Copy these patterns, adapt names.]

### Entity Pattern
```csharp
// From: Likes/Entities/Like.cs
public class Like { ... }
```

### Service Pattern
```csharp
// From: Likes/Services/LikeService.cs
public class LikeService { ... }
```

[etc — only layers relevant to this slice]

## Steps

[Numbered steps using function/class anchors, not line numbers]

1. Create `Entities/Comment.cs` implementing `IEntity`
   - Property: `Id` (Guid), `Content` (string, max 2000), `AuthorId` (Guid FK), `CreatedAt` (DateTimeOffset)
   - Follow the Like entity pattern above
   
2. Add `DbSet<Comment> Comments` to `AppDbContext`
   - Register in `OnModelCreating` following existing entity configurations

[etc]

## Expected Result

**Prerequisites:** [Which depends_on slices must be done]  
**Observable outcome:** `playwright test --grep 'create comment'` passes

The test verifies: user fills comment form → submits → comment appears in list.

## Files Touched

| Action | File | Target |
|--------|------|--------|
| create | Entities/Comment.cs | — |
| modify | Data/AppDbContext.cs | AppDbContext class |
| create | Services/CommentService.cs | — |
| create | Controllers/CommentsController.cs | — |
| create | src/routes/comments/+page.svelte | — |

## Dependencies

Slices that must be DONE before this one executes:
- [slice names, or "none"]
```

**Target length:** 100–300 lines. Max 400. Code examples are guidance, not mandates.

---

## Phases

### Pre-flight

Before any user interaction:

1. Verify `.devflow/` exists (df-init has been run). If not: error E01.
2. Verify `.devflow/memory/` is populated. If not: error E02.
3. Run test suite. On failure: show failures, ask user to fix first or proceed with baseline. Record baseline failures in `plan.md § Baseline Health`. On build failure: HALT (E14).
4. **Skip step 4 if command is `/feature resume`.** Check `.devflow/active` symlink. If exists: "There is an active feature. Use `/feature resume` or remove `.devflow/active` to start fresh." Halt.

### Entry Routing

Parse the command:

- `/feature resume` → jump to **Resume Algorithm**
- `/feature quick <desc>` → set `quick_mode=true`, enter Phase 0 with abbreviated flow
- `/feature <desc>` → set `quick_mode=false`, enter Phase 0

### Phase 0: PRD Interrogation

**Full mode:** Ask clarifying questions one at a time (typically 3–6 questions):
- Who does this? (role/user type)
- What is the observable result?
- What are the boundaries? (what is NOT included)
- Are there performance or scale requirements?
- What does success look like?
- Any dependencies on other features or systems?

**Quick mode:** Ask 2–3 questions maximum.

After questions, produce a structured PRD:

```markdown
## PRD: [Feature Name]

**Actor:** [user type]
**Goal:** [what they want to accomplish]
**Scope:** [what is included]
**Out of scope:** [what is explicitly excluded]
**Success criteria:** [observable, testable outcomes]
**Constraints:** [performance, security, compat requirements]
```

**STOPPING GATE:** Present PRD to user. Ask: "Does this capture what you want to build? Approve or tell me what to change."

Do NOT proceed until explicitly approved.

### Phase 1: Domain Analysis

1. Run `df-explain` to load project structure into context.
2. Identify affected modules: which directories, namespaces, services will this feature touch?
3. Identify a reference feature — an existing feature that is structurally similar. Ask the user: "I'll model the implementation patterns after [X feature]. Does that work, or is there a better reference?"
4. Read ≤5 key files from the reference feature (entity, service, controller, frontend component, test file).
5. Extract patterns into `plan.md § Pattern Library` as verbatim snippets.
6. Identify risks and dependencies: DB migrations needed? External service integrations? Breaking API changes?

**Greenfield fallback (no similar feature):** Use `.devflow/memory/` tech decisions + `CONTRIBUTING.md` for conventions.

Write to `plan.md`:

```markdown
## Domain Analysis

**Affected modules:** [list]
**Reference feature:** [name + path]
**Risks:** [list]
**Dependencies:** [list]

## Pattern Library

[Verbatim snippets from reference feature, labeled by layer]
```

### Phase 2: Slice Planning

Decompose the PRD into vertical slices.

**Vertical slice definition:**
- Thin, user-visible functionality cutting through ≥2 application layers
- Expressed as "[Actor] can [verb] [noun]"
- Independently deployable (partial feature works after this slice)
- Independently testable given only its declared `depends_on` slices

**NOT a vertical slice:**
- Layer-only: "create all entities", "set up all endpoints", "build all components"
- Too thin: single layer ("add Comment entity")
- Too fat: entire feature ("build comment system")
- Technical: refactors, optimizations without user result
- Litmus test: can you write a Playwright e2e a non-developer could understand? If not → not a slice.

**Slice sizing checklist (every slice must pass):**

| Check | Criterion |
|-------|-----------|
| Size | 3–8 files, 3–10 steps, 100–300 line MD |
| Verticality | Touches ≥2 layers (exception: pure DB migration slices) |
| Testability | Result expressible as "Actor can verb noun" |
| Independence | Dependencies on other slices, not on internal steps |
| Context fit | Slice MD + all touched files < 3000 lines total |
| Parallel safety | File overlap analysis complete (see below) |

**Parallel safety analysis:**

For each pair of slices in the same potential batch, compare their file lists:

- **ADDITIVE files (safe to parallelize):** DbContext registrations, DI registrations, route files, barrel exports — both slices add lines in different locations.
- **CONFLICTING files (must serialize):** same function or method body modified by both slices.

If a conflict is found: add an artificial `depends_on` to force serialization. Document reason in `plan.md § Dependency Notes`.

**Build the DAG and batch plan:**

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

**Create plan folder and files:**

1. Create `.devflow/plans/YYYY-MM-DD-<feature-slug>/`
2. Write `plan.md` with PRD, Domain Analysis, Pattern Library, Slice DAG, Execution Batches
3. For each slice: write `slice-N-<slug>.json` and `slice-N-<slug>.md`
4. Create `.devflow/active → plans/YYYY-MM-DD-<feature-slug>/` symlink
5. Create `feature/<feature-slug>` git branch

**STOPPING GATE:** Present slices to user:

```
Slices planned (N total, M batches):

Batch 1 (parallel):
  ✦ slice-1: User can create a comment [db, service, api, frontend]
  ✦ slice-2: User can list comments [api, frontend]

Batch 2:
  ✦ slice-3: User can delete their own comment [service, api, frontend]
    └── depends on: slice-1

Approve to start execution, or tell me what to change.
```

**Rejection handling:** Ask "What would you change?" Adjust: merge/split/reorder/add slices. Regenerate only affected JSON+MD files. Re-present only changed slices. Don't touch already-approved slices.

**Quick mode override:** Auto-generate 1–3 slices without full decomposition. Still requires approval gate. If analysis suggests >3 slices are genuinely needed, warn: "This feature may be too large for quick mode. Continue anyway or switch to full mode?"

### Phase 3: Slice Execution

Execute each batch in sequence. Within a batch, dispatch slices in parallel (full mode) or sequentially (quick mode).

**Worktree setup (full mode, parallel batch):**

For each slice in the batch:
- `df-workspace create feature/<feature-slug>-slice-<N>` to create an isolated worktree
- Record worktree path in slice JSON

**Sequential batches (including quick mode):** Direct commits to `feature/<feature-slug>` branch, no worktrees.

**Per-slice execution loop:**

```
FOR each slice in batch (parallel or sequential):
  
  LOOP (max max_cycles iterations):
  
    1. IMPLEMENT
       Dispatch Implementation Agent:
         - Role:    agents/implementation.md
         - Mission: slice-N-<slug>.md
         - Context: plan.md § Domain Analysis + § Pattern Library
         - Retry:   inject "Prior Work" section (cycle > 1)
       
       Update slice JSON: status=in_progress, cycle+=1
       Mark completed steps[].done as agent reports them
       
    2. TEST (conditional)
       Dispatch Test Agent if:
         - Full mode: always
         - Quick mode: skip if ≤2 steps AND test_cmd passed AND modifies existing behavior
                       always dispatch if: new user-facing behavior, no existing coverage, >3 files changed
       
       Record in slice JSON: test_summary, test_result
       Record skips: test_agent_skipped=true, test_agent_skip_reason="..."
    
    3. REVIEW
       Dispatch Slice Review Agent:
         - Inputs: slice MD + actual implementation files + test results + domain analysis
       
       If verdict=PASS:
         Mark slice status=done
         Break loop
       
       If verdict=FAIL:
         Store review_findings in slice JSON (required_changes array)
         If cycle >= max_cycles:
           Mark slice status=stuck
           Report to user: "Slice N is stuck after N cycles. Review findings: [list]. Options: [fix manually / skip / abort]"
           Break loop
         Else:
           Continue loop (Implementation Agent retries with "Prior Work" context)
  
  END LOOP

END FOR BATCH

AFTER BATCH (full mode, parallel batch):
  Merge all slice branches into feature/<feature-slug>
  Run df-resolve for conflicts
  Auto-resolve additive conflicts (keep both additions)
  Escalate non-additive conflicts to user (indicates planning error)
  Clean up worktrees
```

**Retry dispatch format — "Prior Work" section injected at top of agent prompt:**

```markdown
## Prior Work (Cycle N)

You are retrying this slice. The following work was done in the previous cycle.

**Files created/modified:**
- Entities/Comment.cs — Comment entity with EF Core config
- Services/CommentService.cs — CRUD service, missing transaction wrapper

**Test result:** FAIL — 2/3 tests passed, "delete" test failed

**Review verdict:** FAIL

**Required fixes (do these, nothing else):**
1. Wrap CreateAsync in DbContext.Database.BeginTransactionAsync()
2. Add pagination to GET /api/comments

Read the existing files first. Fix only what is listed. Do NOT re-implement from scratch.
```

### Phase 4: Integration Testing

Run after all batches complete (or all stuck slices reported).

Skip if: quick mode AND single slice AND no stuck slices.

Dispatch Integration Test Agent:
- Inputs: all slice MDs, full plan.md, all changed files
- Writes cross-slice e2e tests
- Runs full test suite
- Reports regressions

If failures: attempt one fix cycle. If still failing: report to user with specific failures.

On completion: append `## Phase 4 Status: COMPLETE` to `plan.md`.

### Phase 5: Final Review

Dispatch Final Review Agent:
- Inputs: full plan.md (PRD + domain analysis + slices), all changed files, full test results, `.devflow/memory/`
- Holistic architecture-aware review (not per-slice quality)
- Output: APPROVED | CHANGES_REQUESTED

If CHANGES_REQUESTED: show findings. Implement required changes. Re-run Phase 5.

On APPROVED: append `## Phase 5 Status: COMPLETE` to `plan.md`.

### Phase 6: Completion

1. **df-sync** — update `.devflow/memory/` with decisions and patterns from this feature
2. **Archive plan** — update `plan.md` status to COMPLETE, keep folder as audit trail
3. **Remove symlink** — `rm .devflow/active`
4. **Invoke finishing-a-development-branch** — delegates merge/PR/cleanup decision to user

**Guard rails — never skip Phase 6, even on abort.** On abort: set status=ABORTED, remove symlink, clean worktrees, keep plan folder and feature branch.

---

## `/feature resume` Algorithm

1. Check `.devflow/active` symlink exists → error E10 if not.
   - If `.devflow/active` missing but a matching plan folder exists: offer to recreate symlink.
2. Read `plan.md` → load feature name, PRD, DAG, batch plan.
3. Read all `slice-*.json` → build status map.
4. Display resume summary:
   ```
   Resuming: [Feature Name]
   
   ✅ slice-1-create-comment (done, cycle 1)
   🔄 slice-2-list-comments (in_progress — step 3 of 5)
   ⏳ slice-3-delete-comment (pending)
   ⚠️ slice-4-edit-comment (stuck — cycle 3)
   
   Current batch: Batch 1
   Next batch: Batch 2 (waiting for Batch 1)
   ```
5. Find first batch with non-done, non-stuck slices.
6. For interrupted `in_progress` slices: show completed `steps[].done` flags, offer restart or continue from last completed step.
7. For `stuck` slices: report to user, ask for direction before resuming.
8. Resume execution at Phase 3 for the identified batch.
9. Edge cases:
   - All slices done → resume at Phase 4
   - Phase 4 complete (recorded in plan.md as `## Phase 4 Status: COMPLETE`) → resume at Phase 5
   - Phase 5 complete (recorded in plan.md as `## Phase 5 Status: COMPLETE`) → run Phase 6
   - Everything done → run Phase 6

---

## Quick Mode

Trigger: explicit `/feature quick <description>` invocation only. Never auto-activate.

| Phase | Full Mode | Quick Mode |
|-------|-----------|------------|
| Phase 0 | 3–6 clarifying questions | 2–3 questions |
| Phase 1 | Full domain analysis | Same |
| Phase 2 | Full decomposition | Auto-generate 1–3 slices, still requires approval |
| Phase 3 | Parallel dispatch, worktrees | Always sequential, direct commits |
| Test Agent | Always dispatch | Skip if: ≤2 steps + test_cmd passed + modifying existing behavior |
| Phase 4 | Always | Skip if single slice, no stuck slices |
| Phase 5 | Always | Same |

If quick mode analysis reveals >3 slices are genuinely needed: warn user and offer to switch to full mode.

---

## Agent Prompt Templates

### `agents/implementation.md`

**Role:** Implement one complete vertical slice of a feature across all affected layers.

**Inputs provided by orchestrator:**
- Slice MD (primary mission briefing)
- Plan domain analysis and pattern library
- Worktree path (if parallel) or current branch (if sequential)
- Prior Work section (if cycle > 1)

**Output format:**
```
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED

What I Implemented:
[Summary of what was built]

Tests:
[Test command run + result]

Files Changed:
- [file path] — [one-line description]

Self-Review:
[Brief honest assessment of quality]

Issues / Concerns:
[If DONE_WITH_CONCERNS or BLOCKED: specific details]
```

**Status definitions:**
- `DONE` — implemented, tests pass, clean
- `DONE_WITH_CONCERNS` — implemented, tests pass, but has known limitations
- `NEEDS_CONTEXT` — blocked by missing information (provide the specific question)
- `BLOCKED` — cannot proceed (missing dependency, environment issue, etc.)

**Constraints:**
- Do not modify files outside the Files Touched table in the slice MD
- Do not refactor unrelated code
- Do not skip writing or running tests
- Commit when done

### `agents/test.md`

**Role:** Write new e2e/integration tests for a completed vertical slice.

**Inputs provided by orchestrator:**
- Slice MD (for result description and test_cmd)
- Files changed list from Implementation Agent
- Test patterns from plan.md Pattern Library

**Output format:**
```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED

Tests Written:
- [test file]: [description of what each test covers]

Test Results:
[Full test output summary]

Coverage Notes:
[What scenarios are covered, any gaps]

Concerns:
[If any]
```

**Constraints:**
- Write only test files
- Do not modify implementation files
- Write e2e or integration tests only (not unit tests)
- Tests must be runnable standalone against the slice result

### `agents/slice-review.md`

**Role:** Review one vertical slice for specification compliance and code quality.

**Inputs provided by orchestrator:**
- Slice MD (spec to verify against)
- All implementation files from files_changed
- Test results from slice JSON
- Domain analysis from plan.md

**Output format:**
```
Verdict: PASS | FAIL

Spec Compliance:
- [ ] Result matches slice MD Expected Result
- [ ] All files in Files Touched table were created/modified
- [ ] Tests exercise the user-visible result
- [other slice-specific checks]

Code Quality:
CRITICAL: [issues that are correctness-blocking or data-loss risks]
IMPORTANT: [issues that would cause problems under normal use]
MINOR: [style, naming, non-urgent improvements]

Test Adequacy:
[Assessment of test coverage]

Required Changes:
[Specific, actionable fixes. Empty if PASS.]
```

**Verdict rules:**
- Any CRITICAL finding → FAIL
- 2+ IMPORTANT findings → FAIL
- Review only — write no code

### `agents/integration-test.md`

**Role:** Verify that multiple completed slices work together correctly as a coherent feature.

**Inputs provided by orchestrator:**
- All slice MDs
- Full plan.md (PRD and batch structure)
- All changed files across all slices

**Output format:**
```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED

Cross-Slice Interactions Verified:
[List of inter-slice scenarios tested]

Tests Written:
- [test file]: [what cross-slice behavior it covers]

Full Suite Results:
[Complete test run output summary]

Regressions:
[Any existing tests that now fail]

Issues:
[If any]
```

**Constraints:**
- Write only test files
- Run the FULL test suite (not just new tests)
- Report any regressions explicitly

### `agents/final-review.md`

**Role:** Architecture-aware review of the complete feature implementation.

**Inputs provided by orchestrator:**
- Full plan.md (PRD, domain analysis, all slices)
- All changed files across all slices
- Full test results
- `.devflow/memory/` (architectural decisions, tech choices)

**Output format:**
```
Verdict: APPROVED | CHANGES_REQUESTED

Feature Assessment:
[Overall evaluation against PRD success criteria]

Findings:
CRITICAL: [Architecture violations, security issues, data integrity risks]
IMPORTANT: [Performance, maintainability, consistency issues]
MINOR: [Style, naming, non-urgent]

Required Changes:
[Specific, actionable list. Empty if APPROVED.]

Summary:
[2-3 sentences on what was built and overall quality]
```

**Constraints:**
- Review only — write no code
- Focus on the full feature holistically, not per-slice quality (slices already reviewed)
- CRITICAL → CHANGES_REQUESTED

---

## Error Reference

| Code | Condition | Recovery |
|------|-----------|----------|
| E01 | `.devflow/` missing — df-init not run | Run `df-init` first |
| E02 | `.devflow/memory/` empty or missing | Run `df-sync` or `df-init` |
| E03 | `.devflow/active` exists on fresh start | Resume or remove symlink manually |
| E04 | User rejected PRD (Phase 0 gate) | Revise PRD per feedback, re-present |
| E05 | User rejected slices (Phase 2 gate) | Adjust per feedback, regenerate affected slices |
| E06 | Slice stuck after max_cycles | Report to user: fix manually / skip / abort |
| E07 | Worktree creation failed | Check disk space, branch conflicts; retry or fall back to sequential |
| E08 | Merge conflict (non-additive) | Indicates planning error; escalate to user for manual resolution |
| E09 | Integration test persistent failure | Report specific failures; ask user to fix or override |
| E10 | `.devflow/active` missing on resume | Check for plan folder; offer to recreate symlink |
| E11 | Final review CHANGES_REQUESTED (>2 cycles) | Escalate to user; present all findings |
| E12 | Slice JSON corrupted or unreadable | Report specific file; ask user to fix or recreate from plan.md |
| E13 | df-explain failed | Retry; if persistent, proceed with degraded domain analysis |
| E14 | Build failure in pre-flight | HALT — fix build before starting feature |
| E15 | All slices in batch stuck | Report all stuck slices; ask user for direction before proceeding |

### Abort Cleanup Protocol

On any unrecoverable error or user abort:
1. Update `plan.md` status → `ABORTED`
2. Remove `.devflow/active` symlink
3. Clean up worktrees (`df-workspace destroy` for each active worktree)
4. Keep plan folder as audit trail
5. Keep `feature/<slug>` branch (for manual recovery)

---

## Breaking Change: df-test

The existing `df-test` reads `.devflow/slices.json`. This design replaces that with per-slice JSON files.

**New behavior:**
1. Resolve `.devflow/active` symlink → plan folder
2. Glob `slice-*.json` from plan folder
3. Sort by `id` field
4. Output in same format as current `df-test` (backward compat output)

**Backward compatibility:**
- If `.devflow/active` symlink is missing, fall back to `.devflow/slices.json` with deprecation warning
- Legacy `slices.json` support remains until V5 tests are updated

**Test additions required:**
- `tests/df-test.bats`: 3 new cases covering per-slice JSON reading, symlink resolution, sort by id
- Existing legacy tests: remain unchanged until deprecated

---

## Guard Rails

These rules are absolute — never bypass regardless of circumstances:

1. Never auto-proceed past Phase 0 or Phase 2 stopping gates
2. Never dispatch a second batch while a batch is still running
3. Never modify `slice-N-<slug>.md` files during execution (they are the source of truth)
4. Always update `slice-*.json` immediately when status changes
5. Never skip Phase 6 (completion/cleanup), even on abort
6. Never mark a slice `done` without a passing review verdict
7. Always run the full test suite in Phase 4 (not just new tests)

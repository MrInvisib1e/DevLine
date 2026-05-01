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

- If build fails (compile error): HALT — "Fix build errors before starting a new feature." (error E14)
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

Extract patterns and write them to `plan.md` under `## Pattern Library`:

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

### Step 4: Write Domain Analysis to plan.md

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

```bash
ln -sf ".devflow/plans/YYYY-MM-DD-<slug>" ".devflow/active"
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

**Quick mode override:** Auto-generate 1-3 slices without full decomposition. Still requires approval gate. If analysis reveals >3 slices are genuinely needed: warn "This feature may be too large for quick mode. Continue anyway or switch to full mode?"

---

## Phase 3: Slice Execution

*(Covered in the continuation of this skill — Task 9)*

---

## Phase 4: Integration Testing

*(Covered in the continuation of this skill — Task 9)*

---

## Phase 5: Final Review

*(Covered in the continuation of this skill — Task 9)*

---

## Phase 6: Completion

*(Covered in the continuation of this skill — Task 9)*

---

## /feature resume

*(Covered in the continuation of this skill — Task 9)*

---

## Error Reference

| Code | Condition | Recovery |
|------|-----------|----------|
| E01 | `.devflow/` missing — df-init not run | Run `/init` first |
| E02 | `.devflow/memory/` empty or missing | Run df-sync or `/init` |
| E03 | `.devflow/active` exists on fresh start | Use `/feature resume` or remove symlink manually |
| E04 | User rejected PRD (Phase 0 gate) | Revise PRD per feedback, re-present |
| E05 | User rejected slices (Phase 2 gate) | Adjust per feedback, regenerate affected slices |
| E06 | Slice stuck after max_cycles | Report to user: fix manually / skip / abort |
| E07 | Worktree creation failed | Check disk space, branch conflicts; retry or fall back to sequential |
| E08 | Merge conflict (non-additive) | Indicates planning error; escalate to user for manual resolution |
| E09 | Integration test persistent failure | Report specific failures; ask user to fix or override |
| E10 | `.devflow/active` missing on resume | Check for plan folder; offer to recreate symlink |
| E11 | Final review CHANGES_REQUESTED (>2 cycles) | Escalate to user; present all findings |
| E12 | Slice JSON corrupted or unreadable | Report specific file; ask user to fix or recreate from plan.md |
| E13 | df-explain failed | Retry once; if persistent, proceed with degraded domain analysis |
| E14 | Build failure in pre-flight | HALT — fix build before starting feature |
| E15 | All slices in batch stuck | Report all stuck slices; ask user for direction |

### Abort Cleanup Protocol

On any unrecoverable error or user abort:
1. Update `plan.md` status → `ABORTED`
2. Remove `.devflow/active` symlink
3. Clean up worktrees (`df-workspace destroy` for each active worktree)
4. Keep plan folder as audit trail
5. Keep `feature/<slug>` branch (for manual recovery)

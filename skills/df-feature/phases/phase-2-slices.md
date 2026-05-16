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

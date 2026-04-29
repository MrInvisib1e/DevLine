# DevFlow — Parallel Execution Design
**Date:** 2026-04-29
**Status:** Approved
**Scope:** Slice dependency graph, parallel agent dispatch via git worktrees, and automated code-reviewer subagent — all as extensions to the feature skill flow defined in `InitialSpec.md`.

---

## 1. Decisions

| Question | Decision |
|---|---|
| Parallelism unit | Slice — independent slices run concurrently, dependent slices are serialized |
| Isolation mechanism | Git worktrees — one per parallel slice, created from HEAD |
| Memory access in worktrees | Read-only — subagents consume `memory.md`, never write graph files |
| df-sync timing | Once per batch after all worktrees merge, not per slice |
| Code review trigger | Automatic after all slices pass, before feature is marked complete |
| Review blocking | `blocking` severity halts the feature skill; `warning`/`note` do not |

---

## 2. Slice Dependency Graph

Each slice in `slices.json` carries a `depends_on` field: a list of slice IDs that must reach `"done"` before this slice can start. This turns the slice plan into a DAG that the executor topologically sorts into ordered batches.

### Schema addition to slices.json

```json
{
  "feature": "comments",
  "approved_at": "2026-04-29T10:00:00Z",
  "slices": [
    {
      "id": 1,
      "name": "User can create a comment",
      "layers": ["db", "service", "api", "frontend"],
      "result": "POST /api/comments returns 201, comment visible in story view",
      "test_cmd": "playwright test --grep 'user can create a comment'",
      "depends_on": [],
      "status": "pending"
    },
    {
      "id": 2,
      "name": "User can delete a comment",
      "layers": ["service", "api", "frontend"],
      "result": "DELETE /api/comments/:id returns 204",
      "test_cmd": "playwright test --grep 'user can delete a comment'",
      "depends_on": [1],
      "status": "pending"
    },
    {
      "id": 3,
      "name": "User can list comments on a story",
      "layers": ["service", "api", "frontend"],
      "result": "GET /api/stories/:id/comments returns paginated list",
      "test_cmd": "playwright test --grep 'user can list comments'",
      "depends_on": [],
      "status": "pending"
    }
  ]
}
```

In this example slices 1 and 3 form the first batch (no dependencies). Slice 2 forms the second batch (depends on slice 1).

### Rules enforced at planning time

- **No circular dependencies** — the skill rejects cycles with an explanation and replans.
- **Valid references only** — `depends_on` may only reference slice IDs that exist in the same plan.
- **Implicit file serialization** — two slices that touch the same file are automatically serialized. The skill infers this by running `df-explain` on each slice's entities and checking for overlapping inbound/outbound edges. It adds a `depends_on` entry even if the developer didn't specify one. This check runs at planning time and again at dispatch time (see §4).

---

## 3. Execution Order

```
build DAG from depends_on fields
topological sort → ordered batches (each batch = slices with all dependencies satisfied)

Batch 1: [slice 1, slice 3]   → independent, run in parallel
Batch 2: [slice 2]            → depends on slice 1, run after batch 1
```

A batch is not started until every slice in all prior batches reaches `"done"`. Within a batch, all slices start simultaneously.

---

## 4. Worktree Lifecycle per Slice

Used only when a batch contains 2 or more slices.

**Pre-dispatch file overlap check:**

Before creating worktrees, the executor re-runs the file overlap check from §2 at runtime against the current `nodes.json`. Any two slices in the batch that share a touched file are serialized — one is moved to the next batch. This catches indirect dependencies that weren't visible during planning.

**Worktree setup:**

```bash
git worktree add .devflow/worktrees/slice-<id> HEAD
mkdir -p .devflow/worktrees/slice-<id>/.devflow
# Absolute symlink — subagents never write graph files
ln -s "$(realpath .devflow/active)" .devflow/worktrees/slice-<id>/.devflow/active
```

**Subagent inputs:**

Each dispatched subagent receives:
- The slice definition (id, name, layers, result, test_cmd)
- Full contents of `memory.md` at dispatch time
- Output of `df-explain` for each entity the slice is expected to touch (inferred from `layers` + graph)
- Absolute path to its worktree

**Subagent contract:**

- Implements all layers for its slice within the worktree
- Runs `df-test <slice-id>` — reads `test_cmd` from `slices.json`, never receives it inline
- On PASS: commits with message `feat(<feature>): slice <id> — <name>` and signals completion
- On first FAIL: fixes inline and retries once
- On second FAIL: signals failure with findings — does not attempt a third fix

**Merge and cleanup (main session):**

```bash
# For each completed worktree, in slice-id order:
git cherry-pick <worktree-commit-sha>

# After all cherry-picks succeed:
git worktree remove .devflow/worktrees/slice-<id>

# One df-sync for the entire batch:
df-sync
```

Cherry-picks are applied in slice-id order regardless of which subagent finished first. If any cherry-pick conflicts, the main session surfaces it and halts — the developer resolves manually.

**On any subagent failure:**

All remaining in-flight subagents are cancelled. Their worktrees are removed without merging. The main session surfaces the failing slice's findings and stops. No partial batch is ever merged.

---

## 5. Memory Consistency During Parallel Execution

Subagents are strictly read-only consumers of the graph:

- They read `memory.md` at dispatch time — a snapshot, not a live feed
- They never write to `nodes.json`, `edges.json`, or `memory.json`
- `df-sync` runs once on the main session after a full batch merges, not per slice

This means a subagent implementing slice 3 does not see graph updates produced by slice 1's implementation — it works from the snapshot taken before the batch started. This is intentional: independent slices by definition should not need each other's graph state. If they do, they should have been serialized via `depends_on`.

---

## 6. Single-Slice Batches

When a batch contains exactly one slice, no worktree is created. The main session implements the slice inline, same as the original sequential flow. The `depends_on` graph still governs ordering — the worktree mechanism is purely a parallelism optimization, not a correctness requirement.

---

## 7. Code-Reviewer Subagent

Fires automatically after all slices reach `"done"`, before the feature is marked complete. Runs in the main worktree — read-only, no isolation needed.

### Inputs

| Input | Source |
|---|---|
| Full feature branch diff | `git diff <base>...HEAD` |
| `memory.md` | `.devflow/active/memory.md` |
| `df-explain` output | Run for every entity touched in the diff |
| Original slice plan | `slices.json` before deletion |

### Review checklist

The subagent reviews against project-specific context, not generic best practices:

- **Convention violations** — calls that break service communication patterns, DI lifetime mismatches, naming deviations from `conventions.naming` in `memory.md`
- **Impact radius gaps** — nodes flagged by `df-explain` as inbound dependents of touched entities that were not themselves touched. These may have had their implicit contracts changed.
- **Slice completeness** — every slice's declared `result` should be verifiable in the diff. A slice whose result is not traceable to code is flagged.
- **Missing test coverage** — new vertical slices without corresponding test changes
- **Contract changes** — cross-service contract modifications without a corresponding `nodes.json`/`edges.json` update (signals that `df-sync` may be stale)
- **Unclassified files** — any file in the diff with no classifier in `config.json`

### Severity levels

| Severity | Meaning | Effect |
|---|---|---|
| `blocking` | Must be resolved before the feature is complete | Feature skill halts, surfaces finding, waits for developer action |
| `warning` | Should be addressed but does not block | Surfaced in output, feature can proceed |
| `note` | Informational observation | Surfaced in output, no action required |

### Output format

```
[DevFlow Review]

BLOCKING (1)
  ▸ CommentService calls StoryService via direct HTTP.
    Convention: inter-service calls use async messaging (see memory.md architecture.patterns).
    Affected: CommentService → StoryService edge (currently emits, changed to direct call).

WARNING (1)
  ▸ CommentCreatedEvent shape changed but FeedService (inbound dependent) was not touched.
    Run df-explain CommentCreatedEvent --depth 2 to assess impact.

NOTE (1)
  ▸ Entities/Comment.cs has no classifier entry in config.json.
    Consider running df-sync to register the pattern.
```

### After review

If no `blocking` findings: `slices.json` is deleted, `df-sync` runs its final pass, feature skill exits cleanly.

If `blocking` findings exist: developer resolves each one, commits the fix, and the review subagent fires again on the updated diff. This repeats until no blocking findings remain.

---

## 8. Full Feature Skill Flow (updated)

```
Phase 1 — Domain Interrogation   (unchanged)
Phase 2 — Slice Planning         build slices.json with depends_on DAG, get approval
Phase 3 — Parallel Execution     topological batches → worktrees → merge → df-sync per batch
Phase 4 — Code Review            code-reviewer subagent → resolve blocking findings
Phase 5 — Memory Sync            df-sync final pass, delete slices.json
```

---

## 9. Worktree Directory Layout

```
.devflow/
  active -> branches/feature-comments/    # symlink (unchanged)
  worktrees/
    slice-1/                              # created at batch start, removed after merge
      .devflow/
        active -> ../../active            # read-only symlink to main memory
    slice-3/
      .devflow/
        active -> ../../active
  sync.lock                               # flock-based concurrency guard
```

`worktrees/` is gitignored. It is always empty outside of an active parallel batch.

# DevFlow — Parallel Execution Design
**Date:** 2026-04-29
**Status:** Approved
**Scope:** Slice dependency graph, parallel agent dispatch via git worktrees, per-slice agent pipeline (implementation → test → review), and final integration test and review agents — all as extensions to the feature skill flow defined in `InitialSpec.md`.

---

## 1. Decisions

| Question | Decision |
|---|---|
| Parallelism unit | Slice — independent slices run concurrently, dependent slices are serialized |
| Isolation mechanism | Git worktrees — one per parallel slice, created from HEAD |
| Memory access in worktrees | Read-only — subagents consume `memory.md`, never write graph files |
| df-sync timing | Once per batch after all worktrees merge, not per slice |
| Per-slice agent order | Implementation → Test (gated) → Slice Review (gated on green) |
| Test gate | Test agent must pass before slice review agent fires |
| Review scope | Slice review agent: per-slice conventions. Final review agent: cross-slice concerns only. |
| Final agents | Integration Test Agent + Final Review Agent fire after all slices complete |
| Review blocking | `blocking` severity halts the feature skill; `warning`/`note` do not |
| Context target | Each agent scoped to under 50k tokens — no accumulated conversation history |

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

**Per-slice agent pipeline:**

Each slice — whether running in a worktree or inline — runs three agents in sequence. Each agent starts with a clean context, scoped to only what it needs. Target: under 50k tokens per agent.

See §7, §8, §9 for full agent specifications. Summary:

```
→ Implementation Agent   receives: slice def + memory.md + df-explain output
→ Test Agent             receives: slice def + slice diff only (no memory.md)
                         gated: fires only after implementation agent completes
→ Slice Review Agent     receives: slice diff + memory.md conventions section + df-explain
                         gated: fires only if test agent passes
```

On any agent failure: remaining in-flight agents for this slice are cancelled. Findings are surfaced. The implementation agent re-engages if fixes are needed. Max 2 fix cycles per slice before escalating to developer.

**Commit (after all three agents pass):**

Commits with message `feat(<feature>): slice <id> — <name>` and signals completion to main session.

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

## 7. Implementation Agent

One per slice. Runs inside the slice's worktree (or inline if batch size is 1).

### Inputs

| Input | Approx tokens |
|---|---|
| Slice definition (id, name, layers, result, test_cmd, depends_on) | ~500 |
| `memory.md` — full | 5–20k |
| `df-explain` output for each entity the slice touches | 2–10k |
| Worktree path | minimal |
| Relevant section of `prd.md` (success criterion this slice maps to + edge cases) | ~1k |

**Total target: under 35k tokens.**

### Contract

- Implements all layers declared in the slice definition
- Does not write tests — that is the test agent's job
- Does not run `df-test` — that is the test agent's job
- Commits once when implementation is complete: `feat(<feature>): slice <id> — <name> [impl]`
- Signals completion to the main session with its commit SHA

---

## 8. Test Agent

One per slice. Fires immediately after the implementation agent commits. Clean context — no prior conversation.

### Inputs

| Input | Approx tokens |
|---|---|
| Slice definition (name, result, test_cmd) | ~300 |
| Slice diff (implementation agent's commit) | 3–10k |
| PRD edge cases relevant to this slice | ~500 |

**Total target: under 15k tokens.**

### Contract

```
run df-test <slice-id>
if PASS:
  write tests that cover the slice's declared result and PRD edge cases
  commit: feat(<feature>): slice <id> — <name> [tests]
  signal PASS to main session

if FAIL:
  diagnose from diff + test output
  write fix + tests
  run df-test <slice-id> again
  if PASS: commit fix + tests, signal PASS
  if FAIL again: signal FAIL with findings — do not attempt third fix
```

The test agent never receives `memory.md` — it reasons only from what the slice is supposed to do and what the code actually does. Keeping its context small keeps its reasoning sharp.

---

## 9. Slice Review Agent

One per slice. Fires only after the test agent signals PASS. Clean context.

### Inputs

| Input | Approx tokens |
|---|---|
| Slice diff (impl + test commits combined) | 5–15k |
| `memory.md` — conventions and architecture sections only (not graph) | 3–8k |
| `df-explain` output for touched entities | 2–8k |
| Slice declared result (to verify code actually delivers it) | ~300 |

**Total target: under 35k tokens.**

### Review checklist (per-slice scope only)

- **Convention violations** — naming deviations, DI lifetime mismatches, service communication pattern breaks
- **Slice result traceability** — the declared result must be traceable in the diff. If it isn't, the slice is incomplete.
- **Impact radius (scoped)** — inbound nodes of touched entities that weren't touched by this slice. May signal a missing change.
- **Test coverage** — the slice's edge cases from the PRD must have corresponding test cases

### Severity levels

| Severity | Effect |
|---|---|
| `blocking` | Implementation agent re-engages with the finding. Slice does not advance until resolved. |
| `warning` | Surfaced, slice advances. |
| `note` | Surfaced, no action required. |

### Output format

```
[DevFlow Slice Review — slice 1: User can create a comment]

BLOCKING (1)
  ▸ CommentService calls StoryService via direct HTTP.
    Convention: inter-service calls use async messaging (memory.md architecture.patterns).
    Fix: replace with event emission via IEventBus.

WARNING (1)
  ▸ Empty body edge case (PRD §edge-cases) has no corresponding test.
    Test agent should add: POST /api/comments with empty body → expect 422.

NOTE (1)
  ▸ Entities/Comment.cs has no classifier in config.json.
    Run df-sync after this feature to register the pattern.
```

---

## 10. Integration Test Agent

Fires after all slices reach `"done"`. One agent, clean context, main worktree (no isolation needed).

### Inputs

| Input | Approx tokens |
|---|---|
| All slice definitions and their test commands | ~2k |
| Full feature branch diff | 10–30k |
| `prd.md` — success criteria and edge cases | ~2k |
| `memory.md` — full | 5–20k |

**Total target: under 60k tokens.**

### Contract

```
run each slice's test_cmd in sequence — verify all still pass together
write one end-to-end test exercising the full feature flow
  (e.g. for CRUD: create → read → edit → delete in a single test)
run the e2e test
if PASS: commit e2e test, signal PASS
if FAIL: surface which cross-slice interaction broke, escalate to developer — do not attempt fix
```

The integration test agent does not re-test slices in isolation — that was the per-slice test agent's job. It tests composition.

---

## 11. Final Review Agent

Fires after the integration test agent passes. One agent, clean context, main worktree.

### Inputs

| Input | Approx tokens |
|---|---|
| Full feature branch diff | 10–30k |
| `memory.md` — full | 5–20k |
| `df-explain` output for every entity touched across all slices | 5–15k |
| `slices.json` (before deletion) | ~2k |
| `prd.md` | ~2k |

**Total target: under 70k tokens.**

### Review checklist (cross-slice scope only — per-slice conventions already reviewed)

- **Cross-slice contract consistency** — error shapes, HTTP status codes, event payloads consistent across Create/Read/Update/Delete
- **Emergent violations** — patterns only visible across the full diff (e.g. inconsistent soft-delete behaviour between Update and Delete slices)
- **Graph drift** — entities touched across multiple slices with conflicting intent in `df-explain`
- **Full impact radius** — inbound nodes affected by the combined diff not caught by per-slice reviews
- **PRD success criteria coverage** — every PRD success criterion must be traceable in the full diff

Same `blocking` / `warning` / `note` severity model. On `blocking`: developer resolves, commits fix, Final Review Agent re-runs on updated diff.

### After final review

No `blocking` findings → `slices.json` deleted, `df-sync` final pass, `prd.md` kept, feature skill exits.

---

## 12. Full Feature Skill Flow (updated)

```
Phase 0 — PRD                   AI interrogates (one question at a time, critical + suggested answers)
                                 AI drafts PRD → developer approves → prd.md written

Phase 1 — Domain Interrogation  Technical questions informed by approved PRD
                                 One at a time, critical, suggested answers, 3–5 questions

Phase 2 — Slice Planning        Reads prd.md + memory.md → vertical slice DAG
                                 Enforces: every slice is a complete user-facing capability
                                 Developer approves plan

Phase 3 — Slice Execution       For each topological batch:
                                   per slice → Implementation Agent  (clean context, <35k)
                                            → Test Agent             (clean context, <15k, gated)
                                            → Slice Review Agent     (clean context, <35k, gated on green)
                                   merge batch, df-sync once

Phase 4 — Integration Test      Integration Test Agent (clean context, <60k)
                                 Verifies cross-slice composition, writes e2e test

Phase 5 — Final Review          Final Review Agent (clean context, <70k)
                                 Cross-slice concerns only — resolves blocking findings

Phase 6 — Memory Sync           df-sync final pass, delete slices.json, keep prd.md
```

---

## 13. Worktree Directory Layout

```
.devflow/
  active -> branches/feature-comments/    # symlink (unchanged)
  branches/
    feature-comments/
      memory.json
      memory.md
      slices.json
      prd.md                              # kept after feature completes
  worktrees/
    slice-1/                              # git worktree root — full repo checkout
      .devflow/
        active -> <abs-path>/.devflow/active   # absolute symlink, read-only
    slice-3/
      .devflow/
        active -> <abs-path>/.devflow/active
  sync.lock                               # flock-based concurrency guard
```

`worktrees/` is gitignored. It is always empty outside of an active parallel batch. The symlink in each worktree uses an absolute path (via `realpath`) to avoid relative path ambiguity across nested directories.

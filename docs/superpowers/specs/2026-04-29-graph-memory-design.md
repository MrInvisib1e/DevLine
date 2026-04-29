# Graph Memory Design
**Date:** 2026-04-29
**Status:** Approved
**Scope:** Replaces flat `memory.json` sections with a typed graph — `nodes.json` + `edges.json`

---

## 1. Decisions

| Question | Decision |
|---|---|
| Relationship model | Hybrid — typed edges with `intent` per relationship |
| Node types | 4 built-in + custom types defined in `config.json` |
| Relationship discovery | Static analysis for structure, AI (batched) for intent only |
| Storage | Split files — `nodes.json` + `edges.json` |

---

## 2. Migration from Flat Memory

The graph model replaces three sections that previously lived in `memory.json`:

| Removed from `memory.json` | Now lives in |
|---|---|
| `entities` | `nodes.json` (type: `entity`) |
| `routes` | `nodes.json` (type: `route`) |
| `contracts` | `nodes.json` (type: `contract`) |

`df-init` removes these keys from any existing `memory.json` and rebuilds them into `nodes.json` and `edges.json`. The `stack`, `architecture`, and `conventions` sections of `memory.json` are unchanged. Scripts must never write entity/route/contract data into `memory.json` — it will be ignored and will cause drift.

---

## 3. File Structure

Added to `.devflow/active/` alongside existing files:

```
.devflow/active/
  memory.json       # stack, architecture, conventions (unchanged)
  memory.md         # auto-generated render — skills read this
  nodes.json        # graph node definitions
  edges.json        # graph relationships
  slices.json       # active slice plan (feature skill)
```

---

## 4. nodes.json Schema

```json
{
  "schema_version": 1,
  "nodes": [
    {
      "id": "entity:Comment",
      "name": "Comment",
      "type": "entity",
      "file": "Entities/Comment.cs",
      "intent": "Soft-deletable — hide, never purge",
      "confidence": "high",
      "last_seen_sha": "a3f9c12"
    }
  ]
}
```

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier — format `<type>:<name>` (e.g. `entity:Comment`, `service:CommentService`). Guarantees no collision across types. |
| `name` | string | Display name |
| `type` | string | Built-in or custom node type |
| `file` | string | Relative path from repo root |
| `intent` | string | AI-inferred: the *why* behind this node's existence |
| `confidence` | `"high" \| "inferred" \| "ai"` | Source of classification |
| `last_seen_sha` | string | Last commit where this file appeared in a diff |
| `stale` | boolean | Omitted when false; set to `true` when the node is stale (see §7 for staleness rules) |

### Built-in Node Types

`entity`, `service`, `route`, `contract`

### Custom Node Types

Defined per-project in `config.json`:

```json
"node_types": {
  "custom": ["job", "middleware", "saga"]
}
```

---

## 5. edges.json Schema

```json
{
  "schema_version": 1,
  "edges": [
    {
      "from": "entity:Comment",
      "to": "entity:User",
      "rel": "depends_on",
      "intent": "author ownership",
      "last_seen_sha": "a3f9c12"
    },
    {
      "from": "service:CommentService",
      "to": "entity:Comment",
      "rel": "uses",
      "intent": "CRUD — create, soft-delete, list by story",
      "last_seen_sha": "a3f9c12"
    },
    {
      "from": "entity:Comment",
      "to": "entity:Story",
      "rel": "depends_on",
      "intent": "parent context",
      "last_seen_sha": "a3f9c12"
    }
  ]
}
```

### Fields

| Field | Type | Description |
|---|---|---|
| `from` | string | Source node `id` (format: `type:name`) |
| `to` | string | Target node `id` (format: `type:name`) |
| `rel` | string | Relationship type |
| `intent` | string | AI-inferred: the *why* behind this relationship |
| `last_seen_sha` | string | Last commit where this edge was confirmed |
| `stale` | boolean | Omitted when false; set to `true` when either endpoint is stale (see §7 for staleness rules) |

### Built-in Relationship Types

| Type | Meaning |
|---|---|
| `depends_on` | Requires another node to function |
| `uses` | Calls or instantiates |
| `persisted_in` | Maps to a DB table or collection |
| `implements` | Satisfies an interface or contract |
| `emits` | Publishes an event or message |
| `handles` | Consumes an event or message |

### Relationship Type Validation

`rel` is validated against a closed set on every write. Built-in types plus any values declared in `config.json` `edge_rel_types.custom` are the only valid values. Any write attempt with an unrecognised `rel` logs a warning and the edge is skipped — it is never silently written with a malformed type. This prevents typo drift (`"depend_on"` vs `"depends_on"`) from corrupting the graph.

---

## 6. df-sync Pipeline

Runs on every hook invocation and after every skill completion.

### Concurrency Lock

`df-sync` acquires `.devflow/sync.lock` via `flock` (non-blocking) before touching any graph file. A second concurrent invocation exits immediately with `[DevFlow] sync already running — skipping`. Released on exit including SIGTERM. Falls back to a PID-file lock on filesystems where `flock` is unavailable.

### Atomic Writes

All writes to `nodes.json` and `edges.json` use a temp-file + atomic rename:

```
write → <file>.tmp  →  fsync  →  rename <file>.tmp → <file>
```

`config.json` `"dirty": true` is set at the start of every sync run and cleared only after all files are renamed. Skills that find `"dirty": true` on startup re-run `df-sync` before reasoning.

### Failure Modes

| Failure | Behaviour |
|---|---|
| AI intent batch times out | Retry once after 5s. If still failing: write nodes/edges without `intent`, set `confidence: "ai"`, log warning. Never block on intent. |
| Process killed mid-write | `dirty: true` survives. Next skill invocation re-runs `df-sync` from scratch. |
| Classifier glob throws | Skip the file, log warning, continue. |

### Per changed file in diff:

**Step 1 — Classify node type**
Run hybrid classifier (heuristics → AI fallback). Write or update entry in `nodes.json`. Set `confidence` and `last_seen_sha`.

**Step 2 — Static analysis → edges**
Parse `using`/`import` statements, inheritance, interface implementations, function signatures. Extract raw edges `{ from, to, rel }` — no intent yet. Write to `edges.json`.

**Step 3 — Staleness sweep**
Two independent staleness conditions:

- **Hard stale**: the node's `file` no longer exists in HEAD → set `"stale": true` immediately, regardless of commit count.
- **Soft stale**: the file still exists but hasn't appeared in any diff for `edge_staleness_threshold` commits → set `"stale": true`. Indicates the node may be accurate but unverified; skills surface it as a warning, not a blocker.

Edges inherit stale from either endpoint — if either `from` or `to` is stale, the edge is also marked stale. Skills surface stale nodes before reasoning begins.

### Batched once per sync:

**AI Call — intent inference**
One Claude call receives: all new/updated nodes without `intent` + all new edges without `intent` + the diff. Returns intent strings only. Never re-infers structure. Also classifies any nodes unresolved by heuristics in Step 1.

Intent re-inference is triggered when a node's `file` changes by more than 30 lines in the diff — the existing `intent` string is cleared and the node is included in the next AI batch. This threshold is not configurable; it is a fixed heuristic. Nodes with cleared intent have their `confidence` set to `"ai"` until re-inferred.

**Step 4 — Pattern learning**
AI-classified nodes write their inferred path pattern back to `config.json classifiers`. Same file type → heuristics next time.

**Step 5 — Regenerate memory.md**
Render `memory.json` + `nodes.json` + `edges.json` into a single markdown file. Skills read this. Update `last_synced` SHA in `config.json`.

### memory.md graph section (example)

```markdown
## Graph

Comment [entity] — Soft-deletable — hide, never purge
  depends_on → User (author ownership)
  depends_on → Story (parent context)
  persisted_in → comments (soft-delete via is_hidden flag)

CommentService [service] — Owns all comment mutations
  uses → Comment (CRUD — create, soft-delete, list by story)
  uses → ICommentRepository (data access)
  emits → CommentCreatedEvent (notifies feed service)
```

---

## 7. Branch Conflict Resolution

When two branches both modify `nodes.json` or `edges.json`, conflicts are detected on the merge-base diff — the same trigger as `memory_conflicts.json` in the base spec.

### Conflict detection

On branch switch, `df-sync --branch-switch` compares the incoming branch's graph files against the current branch's graph files using the merge-base SHA as the common ancestor. Conflicts are recorded in `graph_conflicts.json`:

```json
{
  "nodes": [
    {
      "id": "entity:Comment",
      "conflict": "intent",
      "branch_a": "Soft-deletable — hide, never purge",
      "branch_b": "Hard-deleted after 90 days"
    }
  ],
  "edges": [
    {
      "from": "service:CommentService",
      "to": "entity:Comment",
      "rel": "uses",
      "conflict": "intent",
      "branch_a": "CRUD — create, soft-delete, list by story",
      "branch_b": "read-only after comment is locked"
    }
  ]
}
```

### Resolution rules

- **Non-conflicting nodes/edges**: merged automatically — the incoming branch wins on its own additions; both branch additions are kept.
- **`intent` conflicts**: flagged in `graph_conflicts.json`. The `feature` and `fix` skills check for this file on startup and surface conflicts before proceeding. The developer resolves by accepting one value or writing a new one; the winning value is written back and `graph_conflicts.json` is deleted.
- **`stale` conflicts**: ignored — the staleness sweep always re-evaluates from HEAD, so stale state is never merged.

No silent merge. If `graph_conflicts.json` exists, skills block reasoning on affected nodes until resolved.

---

## 8. df-explain

`df-explain <input> [--depth N]`

### Input forms

| Form | Example | Behavior |
|---|---|---|
| Node name | `df-explain Comment` | Exact or fuzzy match against `nodes.json` |
| File path | `df-explain Entities/Comment.cs` | Match by `file` field |
| Depth flag | `df-explain --depth 2 Comment` | BFS depth (default: 1, direct neighbours only) |

### Traversal algorithm

1. Resolve input to node id in `nodes.json`
2. BFS outbound edges — what this node depends on
3. BFS inbound edges — what depends on this node (impact radius)
4. Flag any stale nodes in the result
5. Output structured report

### Output format

```
[Comment] entity — Soft-deletable — hide, never purge
file: Entities/Comment.cs
confidence: high

DEPENDS ON (2)
  → User [entity] — author ownership
  → Story [entity] — parent context

DEPENDED ON BY (3) — changing Comment affects these:
  ← CommentService [service] — CRUD operations
  ← CommentController [route] — exposes POST /api/comments
  ← CommentCreatedEvent [contract] — carries comment payload

PERSISTED IN
  → comments table — soft-delete via is_hidden flag

[DevFlow] 3 nodes depend on Comment.
Changing its shape will affect CommentService, CommentController, and CommentCreatedEvent.
```

If no node is found:
```
[DevFlow] No memory found for "Comment". It may need a df-sync or a classifier entry.
```

---

## 8a. df-resolve — Conflict Resolution

`df-resolve` is the interactive tool for resolving conflicts recorded in `memory_conflicts.json` and `graph_conflicts.json`. Developers never edit these JSON files by hand.

### Usage

```bash
df-resolve              # resolve all pending conflicts one by one
df-resolve --file graph  # resolve only graph_conflicts.json conflicts
df-resolve --file memory # resolve only memory_conflicts.json conflicts
```

### Interaction flow

For each conflicted item, `df-resolve` prints:

```
[DevFlow] Conflict: entity:Comment — intent
  Branch A: "Soft-deletable — hide, never purge"
  Branch B: "Hard-deleted after 90 days"

Accept [A], accept [B], or write a new value [W]? (A/B/W):
```

On selection:
- `A` or `B`: writes the chosen value to `nodes.json` for that node, removes the entry from `graph_conflicts.json`.
- `W`: opens the system `$EDITOR` with the A value pre-filled. On save, the written value is used.

After all conflicts are resolved, `df-resolve` deletes `graph_conflicts.json` (or `memory_conflicts.json`), runs `df-sync` to regenerate `memory.md`, and prints `[DevFlow] All conflicts resolved. Memory updated to <HEAD-sha>.`

### Unresolved conflicts block skills

If a skill starts and detects `graph_conflicts.json` or `memory_conflicts.json`, it prints:

```
[DevFlow] Unresolved graph conflicts detected. Run df-resolve before proceeding.
Affected nodes: entity:Comment, service:CommentService
```

The skill halts — it does not proceed with contested intent. Running `df-resolve` unblocks it.

---

## 9. Integration with Existing Skills

### feature skill
Reads `memory.md` graph section when planning slices. Can ask `df-explain` on any entity it plans to touch before writing code.

### fix skill
Before forming a hypothesis, runs `df-explain` on the failing endpoint or entity. Uses the inbound edge list to scope the search — only reads files that the graph says are connected.

### review skill
After reading the diff, runs `df-explain` on every changed node. Flags any inbound nodes that weren't touched by the PR but whose behaviour may have changed.

### mem-sync skill

Invoked automatically via a `post-commit` git hook installed by `df-init`. Not intended for manual invocation (though it is safe to call manually).

**Flow:**

```
1. Read config.json — get last_synced SHA
2. If last_synced == HEAD: print "[DevFlow] Memory already current." and exit 0
3. Run df-sync (diff HEAD vs last_synced, classify, patch nodes.json/edges.json/memory.json, regenerate memory.md)
4. Verify all three files (nodes.json, edges.json, memory.json) have last_seen_sha / last_synced == HEAD
5. If any file is out of sync: print "[DevFlow] Sync failed — <file> is still at <sha>. Re-running df-sync." and repeat step 3 once
6. If still out of sync after retry: print "[DevFlow] mem-sync failed. Run df-sync manually and check for lock or write errors." and exit 1
7. On success: print "[DevFlow] Memory synced to <HEAD sha>." and exit 0
```

**Failure contract:** `mem-sync` never silently exits with stale memory. It either succeeds (exit 0, memory == HEAD) or fails loudly (exit 1, developer must resolve). The `feature` and `fix` skills check this on startup via the `last_synced` divergence check — if `mem-sync` failed, they will re-run `df-sync` themselves before proceeding.

---

## 10. config.json additions

```json
{
  "node_types": {
    "custom": ["job", "middleware", "saga"]
  },
  "edge_staleness_threshold": 30,
  "edge_rel_types": {
    "builtin": ["depends_on", "uses", "persisted_in", "implements", "emits", "handles"],
    "custom": []
  },
  "graph_limits": {
    "max_nodes": 2000,
    "max_edges": 10000,
    "prune_min_age_commits": 90
  },
  "classifiers": {
    "entities":    ["**/Entities/*.cs", "**/Models/*.cs"],
    "routes":      ["*Controller.cs", "*Endpoint.cs"],
    "contracts":   ["**/Contracts/**", "**/Events/**"],
    "services":    ["**/Services/*.cs"]
  }
}
```

`edge_staleness_threshold`: number of commits after which an unseen node or edge is marked `stale: true`. Applies to both files. Default: 30.

`edge_rel_types`: closed set of valid `rel` values. `builtin` is fixed; `custom` is project-defined. Any unrecognised value on write is rejected with a warning.

`graph_limits.max_nodes` / `graph_limits.max_edges`: when exceeded, `df-sync` prunes nodes that are `stale: true` AND whose `last_seen_sha` is more than `prune_min_age_commits` commits behind HEAD AND have no inbound edges. Their edges are deleted with them. `prune_min_age_commits` defaults to 90 — this intentional gap between `edge_staleness_threshold` (30) and the prune floor (90) gives stale nodes time to be re-discovered before deletion. If pruning doesn't bring the count below the limit, `df-sync` logs a warning and continues — it never silently drops non-stale nodes.

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

## 2. File Structure

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

## 3. nodes.json Schema

```json
{
  "schema_version": 1,
  "nodes": [
    {
      "id": "Comment",
      "name": "Comment",
      "type": "entity",
      "file": "Entities/Comment.cs",
      "intent": "Soft-deletable — hide, never purge",
      "confidence": "high",
      "last_seen_sha": "a3f9c12",
      "stale": false
    }
  ]
}
```

### Fields

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier — defaults to `name` |
| `name` | string | Display name |
| `type` | string | Built-in or custom node type |
| `file` | string | Relative path from repo root |
| `intent` | string | AI-inferred: the *why* behind this node's existence |
| `confidence` | `"high" \| "inferred" \| "ai"` | Source of classification |
| `last_seen_sha` | string | Last commit where this file appeared in a diff |
| `stale` | boolean | True if file no longer exists in HEAD |

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

## 4. edges.json Schema

```json
{
  "schema_version": 1,
  "edges": [
    {
      "from": "Comment",
      "to": "User",
      "rel": "depends_on",
      "intent": "author ownership",
      "last_seen_sha": "a3f9c12"
    },
    {
      "from": "CommentService",
      "to": "Comment",
      "rel": "uses",
      "intent": "CRUD — create, soft-delete, list by story",
      "last_seen_sha": "a3f9c12"
    },
    {
      "from": "Comment",
      "to": "comments",
      "rel": "persisted_in",
      "intent": "soft-delete via is_hidden flag",
      "last_seen_sha": "a3f9c12",
      "stale": false
    }
  ]
}
```

### Fields

| Field | Type | Description |
|---|---|---|
| `from` | string | Source node `id` |
| `to` | string | Target node `id` |
| `rel` | string | Relationship type |
| `intent` | string | AI-inferred: the *why* behind this relationship |
| `last_seen_sha` | string | Last commit where this edge was confirmed |
| `stale` | boolean | True if either endpoint no longer exists in HEAD |

### Built-in Relationship Types

| Type | Meaning |
|---|---|
| `depends_on` | Requires another node to function |
| `uses` | Calls or instantiates |
| `persisted_in` | Maps to a DB table or collection |
| `implements` | Satisfies an interface or contract |
| `emits` | Publishes an event or message |
| `handles` | Consumes an event or message |

---

## 5. df-sync Pipeline

Runs on every hook invocation and after every skill completion.

### Per changed file in diff:

**Step 1 — Classify node type**
Run hybrid classifier (heuristics → AI fallback). Write or update entry in `nodes.json`. Set `confidence` and `last_seen_sha`.

**Step 2 — Static analysis → edges**
Parse `using`/`import` statements, inheritance, interface implementations, function signatures. Extract raw edges `{ from, to, rel }` — no intent yet. Write to `edges.json`.

**Step 3 — Staleness sweep**
Any node or edge whose `last_seen_sha` is older than N commits and whose file no longer exists in HEAD → set `"stale": true`. Skills surface stale nodes before reasoning.

### Batched once per sync:

**AI Call — intent inference**
One Claude call receives: all new/updated nodes without `intent` + all new edges without `intent` + the diff. Returns intent strings only. Never re-infers structure. Also classifies any nodes unresolved by heuristics in Step 1.

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

## 6. df-explain

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

## 7. Integration with Existing Skills

### feature skill
Reads `memory.md` graph section when planning slices. Can ask `df-explain` on any entity it plans to touch before writing code.

### fix skill
Before forming a hypothesis, runs `df-explain` on the failing endpoint or entity. Uses the inbound edge list to scope the search — only reads files that the graph says are connected.

### review skill
After reading the diff, runs `df-explain` on every changed node. Flags any inbound nodes that weren't touched by the PR but whose behaviour may have changed.

### mem-sync skill
Triggers `df-sync` after every commit. Verifies that `nodes.json` and `edges.json` are consistent with the new HEAD before marking sync complete.

---

## 8. config.json additions

```json
{
  "node_types": {
    "custom": ["job", "middleware", "saga"]
  },
  "edge_staleness_threshold": 30,
  "classifiers": {
    "entities":    ["**/Entities/*.cs", "**/Models/*.cs"],
    "routes":      ["*Controller.cs", "*Endpoint.cs"],
    "contracts":   ["**/Contracts/**", "**/Events/**"],
    "services":    ["**/Services/*.cs"]
  }
}
```

`edge_staleness_threshold`: number of commits after which an unseen node or edge (one that hasn't appeared in any diff) is marked `stale: true`. Applies to both `nodes.json` and `edges.json`. Default: 30.

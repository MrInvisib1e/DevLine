# DevFlow — Vertical 3: df-explain + df-test + fix skill
**Version:** 1.0
**Date:** 2026-04-30
**Status:** Approved

---

## 1. Scope

This vertical delivers three pieces:

1. **`bin/df-explain`** — diagnostic script: resolves a node name or file path, runs BFS traversal of the graph, prints a structured human-readable report.
2. **`bin/df-test`** — slice test runner: reads `slices.json`, executes the `test_cmd` for a named slice, writes the result back to `slices.json`.
3. **`skills/fix/SKILL.md`** — AI skill: memory-aware bug fix flow using `df-explain` and `df-test`.

**Out of scope for V3:** `df-workspace`, `df-export`, `df-resolve`, `feature` skill, `review` skill.

---

## 2. Decisions

| Question | Decision |
|---|---|
| `df-explain` output format | Human-readable only (no `--json` flag). Skills read `nodes.json`/`edges.json` directly for structured data. |
| BFS depth bounds | Default 1, hard cap 5. Depth 0 = node only, no edges. |
| `df-test` output | Wrap with `[DevFlow]` headers + write result back to `slices.json` (Option C). |
| Staleness pre-check in fix skill | Auto-run `df-sync` if dirty or SHA diverged (Option A). |
| Node inference in fix skill | AI infers node from description, shows it to developer for confirmation before calling `df-explain` (Option C). |

---

## 3. `bin/df-explain`

### Interface

```bash
df-explain <name-or-path> [--depth N]
df-explain --node <exact-id> [--depth N]
df-explain --version
```

- `<name-or-path>`: node name (any case) or file path
- `--depth N`: BFS depth (default: 1, hard cap: 5). Depth 0 = node card only, no edges.
- `--node <exact-id>`: bypass name resolution, require exact case-sensitive node ID

### Prerequisites

- Must be inside a git repo (check with `git rev-parse --git-dir`)
- `jq` must be installed
- CI mode: if no `.devflow/` directory → exit 0 silently

### Name Resolution Algorithm

Attempted in order, stopping at the first match:

1. **Exact match** — compare input against all node `id` fields (case-sensitive). One match → use it.
2. **Case-insensitive exact match** — compare case-insensitively against all node `id` fields. One match → use it.
3. **Substring match** — check if input is a case-insensitive substring of any node `id`. One match → use it. Multiple matches → print list and exit 1:
   ```
   [DevFlow] Multiple matches for "comment":
     1. entity:Comment
     2. service:CommentService
     3. route:CommentController
   Specify a full node name or use df-explain --node <exact-name>.
   ```
4. **File path match** — compare input against all node `file` fields (exact path). One match → use it.
5. **No match** → print `[DevFlow] No memory found for "<input>". It may need a df-sync or a classifier entry.` → exit 1

`--node` bypasses all of the above; if the exact ID is not found → print `[DevFlow] Node "<id>" not found in nodes.json.` → exit 1.

### BFS Traversal

Starting from the resolved node:

1. Collect **outbound** edges: all edges where `from == node.id` (what this node depends on)
2. Collect **inbound** edges: all edges where `to == node.id` (what depends on this node)
3. For each neighbour at depth 1, if depth > 1: recurse outbound + inbound up to the remaining depth
4. Deduplicate nodes seen across recursion (prevent cycles)
5. Flag any node where `stale != false` with `[STALE]`

Hard cap: depth cannot exceed 5 regardless of `--depth` value. If `--depth` > 5, use 5 silently.

### Output Format

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

[DevFlow] 3 nodes depend on Comment.
Changing its shape will affect CommentService, CommentController, and CommentCreatedEvent.
```

- If a node in the traversal has no `intent` → print `(no intent recorded)` in its place
- If a node is stale → append `[STALE: deleted]` or `[STALE: aged]` to its line
- If depth 0 → print node card only, no DEPENDS ON / DEPENDED ON BY sections
- If no outbound edges → omit DEPENDS ON section entirely
- If no inbound edges → omit DEPENDED ON BY section entirely
- Summary line at the end only if inbound count > 0

### Error Messages

| Condition | Message | Exit |
|---|---|---|
| Not a git repo | `[DevFlow] Not a git repo.` | 1 |
| No `.devflow/` | (silent) | 0 |
| `nodes.json` or `edges.json` missing | `[DevFlow] Memory not initialised. Run df-init first.` | 1 |
| Multiple substring matches | List + `Specify a full node name...` | 1 |
| No match | `[DevFlow] No memory found for "<input>". It may need a df-sync or a classifier entry.` | 1 |
| `--node` exact ID not found | `[DevFlow] Node "<id>" not found in nodes.json.` | 1 |
| `jq` not installed | `[DevFlow] Missing prerequisite: jq` | 1 |

---

## 4. `bin/df-test`

### Interface

```bash
df-test <slice-id>     # run test for a specific slice
df-test --list         # list all slices with current status
df-test --version
```

- `slice-id` is an integer matching a `slices.json` entry's `id` field
- `DEVFLOW_TEST_CMD` env var overrides `test_cmd` from `slices.json` (CI escape hatch)

### Prerequisites

- Must be inside a git repo
- `jq` must be installed
- If no `.devflow/` and no `DEVFLOW_TEST_CMD` → `[DevFlow] No test command found. Set DEVFLOW_TEST_CMD or run df-init.` → exit 1

### Happy Path

1. Read `.devflow/active/slices.json`
2. Find the slice with `id == <slice-id>`
3. Determine test command: `DEVFLOW_TEST_CMD` if set, otherwise slice's `test_cmd`
4. Print `[DevFlow] Running slice <id>: <name>`
5. Execute test command — pipe stdout/stderr through unchanged
6. On exit 0:
   - Print `[DevFlow] PASS`
   - Set `status: "done"` on the slice in `slices.json` (atomic write: temp → sync → rename)
   - Exit 0
7. On exit non-zero:
   - Print `[DevFlow] FAIL (exit <N>)`
   - Set `status: "failed"` on the slice in `slices.json` (atomic write)
   - Exit with the same non-zero code

### `--list` Output

```
Slice plan: comments (approved 2026-04-30T10:00:00Z)
  [done]       1  User can create a comment
  [failed]     2  User can delete a comment
  [pending]    3  User can list comments on a story
  [in-progress] 4  User can edit a comment
```

### Error Messages

| Condition | Message | Exit |
|---|---|---|
| Not a git repo | `[DevFlow] Not a git repo.` | 1 |
| No `slices.json` and no `DEVFLOW_TEST_CMD` | `[DevFlow] No slice plan found. Run the feature skill to create one.` | 1 |
| Slice ID not found | `[DevFlow] Slice <id> not found in slices.json.` | 1 |
| `test_cmd` is null or empty (and no `DEVFLOW_TEST_CMD`) | `[DevFlow] Slice <id> has no test_cmd defined.` | 1 |
| `jq` not installed | `[DevFlow] Missing prerequisite: jq` | 1 |

---

## 5. `skills/fix/SKILL.md`

### Trigger

```
/fix "<description of what's broken>"
```

Examples:
- `/fix "comments endpoint returns 500 on empty body"`
- `/fix "UserService throws NullReferenceException on login"`

### Pre-flight Checks (before any reasoning)

Run in this order:

1. **Memory staleness check:** Read `.devflow/config.json`. If `dirty: true` OR `last_synced` ≠ `git rev-parse HEAD`:
   - Run `df-sync` automatically
   - Print `[DevFlow] Memory was stale — synced to <sha> before proceeding.`
2. **Conflict check:** If `.devflow/active/graph_conflicts.json` exists:
   - Print conflicted node IDs
   - Tell developer to run `df-resolve` first
   - Halt — do not proceed

### Step 1 — Node Inference + Confirmation

AI parses the description and identifies the most likely node:

```
I think this is about [CommentController] (route) — Entities/CommentController.cs.
Is that right? (Y / different node)
```

- If **Y** or developer confirms → proceed with that node
- If **different node** → ask developer to specify (name or file path), then use that
- Call `df-explain <node>` with default depth 1
- Read and internalize the `df-explain` output

### Step 2 — Context Loading

Read in this order, **before reading any source files**:

1. `df-explain` output from Step 1 (already loaded)
2. `.devflow/active/memory.md` — architecture and conventions sections only

Do not open any source code files yet.

### Step 3 — Hypothesis Formation

State a hypothesis explicitly before reading any code. Format:

```
Hypothesis [cycle 1/3]: The empty body isn't validated at the API layer —
CommentController passes null to CommentService which throws on null access.

Files to read:
  - Entities/CommentController.cs  (inbound route from df-explain)
  - Services/CommentService.cs     (outbound service dependency)

Reading these files — does this look right? (Y / adjust)
```

Developer confirms or adjusts the file list. Then read only those files.

### Cycle Loop (max 3 cycles)

Each cycle = one hypothesis + file reads + fix attempt + test run.

**Fix:**
- Apply the fix to the identified files
- Do not touch files outside the hypothesis scope unless the fix requires it

**Test command selection:**
- If `.devflow/active/slices.json` exists AND the `feature` field matches the current git branch name AND at least one slice has `status` ≠ `"done"` (i.e. the feature is still in progress):
  - Identify the most relevant slice (the one whose `layers` or `result` best matches the broken thing)
  - Run `df-test <slice-id>`
- Otherwise:
  - Run `test_cmd` from `config.json`
- If no test command is available anywhere: tell developer to provide one before continuing

**On PASS:**
- Break out of cycle loop
- Print success summary (see below)

**On FAIL:**
- State what the failure reveals about the hypothesis
- Revise hypothesis
- Identify new/additional files if needed
- Start next cycle (increment cycle counter)

**After 3 failed cycles:**
- Do not attempt a 4th cycle
- Surface all findings:
  ```
  [DevFlow] Could not fix after 3 cycles. Here's what I found:

  Cycle 1: Hypothesis about null validation — patched controller but test still fails.
  Cycle 2: Looked at serialisation layer — no issue found there.
  Cycle 3: Traced to middleware order issue — fix attempted but introduced regression.

  Current state of the code: [describe what was changed and reverted if any]
  Suggested next steps: [manual investigation hints]
  ```

### Output on Success

```
[DevFlow] Fixed in <N> cycle(s).
Hypothesis: <winning hypothesis>
Files changed: <list>
Suggested commit: fix: <short description>
```

### Error Reference

| Condition | Behaviour |
|---|---|
| Memory stale before start | Auto-run df-sync, print message, continue |
| `graph_conflicts.json` exists | Print conflicted nodes, halt |
| `df-explain` returns no match | Ask developer to specify a different starting node |
| No test command available | Ask developer to provide test command before continuing |
| 3 cycles exhausted | Surface findings + diagnosis, do not attempt 4th cycle |
| `df-test` not on PATH | Fall back to `test_cmd` from `config.json` with warning: `[DevFlow] df-test not found — using config test_cmd` |

---

## 6. Tests

### `tests/df-explain.bats`

| Test | Description |
|---|---|
| `--version` | Prints version string, exits 0 |
| exact match | Resolves `entity:Comment` exactly |
| case-insensitive match | `comment` resolves to `entity:Comment` |
| substring single match | `Comm` resolves to `entity:Comment` |
| substring multiple matches | Lists options, exits 1 |
| file path match | `Entities/Comment.cs` resolves to `entity:Comment` |
| no match | Prints no-memory message, exits 1 |
| `--node` exact | Resolves exact node ID directly |
| `--node` not found | Prints not-found message, exits 1 |
| depth 0 | Node card only, no edges sections |
| depth 1 (default) | Direct neighbours shown |
| depth 2 | Second-degree neighbours shown |
| depth cap | `--depth 99` treated as depth 5 |
| stale node flagged | `[STALE: aged]` appears in output |
| no outbound edges | DEPENDS ON section omitted |
| no inbound edges | DEPENDED ON BY section omitted |
| not-git-repo | Prints error, exits 1 |
| no `.devflow/` | Exits 0 silently |
| missing nodes.json | Prints not-initialised message, exits 1 |

### `tests/df-test.bats`

| Test | Description |
|---|---|
| `--version` | Prints version string, exits 0 |
| happy path PASS | Runs test_cmd, prints PASS, sets status done, exits 0 |
| happy path FAIL | Runs test_cmd, prints FAIL, sets status failed, exits non-zero |
| exit code passthrough | Exit code from test_cmd is preserved |
| status written atomically | `slices.json` updated correctly after PASS |
| `--list` | Prints all slices with statuses |
| slice not found | Prints error, exits 1 |
| no test_cmd | Prints no-test-cmd error, exits 1 |
| `DEVFLOW_TEST_CMD` override | Uses env var instead of slices.json test_cmd |
| no slices.json + no env | Prints no-slice-plan error, exits 1 |
| not-git-repo | Prints error, exits 1 |

---

## 7. Definition of Done

- [ ] `bin/df-explain` passes `shellcheck` with zero warnings
- [ ] All `tests/df-explain.bats` tests pass
- [ ] `bin/df-test` passes `shellcheck` with zero warnings
- [ ] All `tests/df-test.bats` tests pass
- [ ] `skills/fix/SKILL.md` written
- [ ] `DEVFLOW_AI_MOCK=1` works for all scripts
- [ ] Both scripts work end-to-end on the DevFlow repo itself
- [ ] No regressions in `tests/df-init.bats` or `tests/df-sync.bats`

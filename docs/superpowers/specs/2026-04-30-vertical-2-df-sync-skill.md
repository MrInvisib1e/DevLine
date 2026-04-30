# df-sync + mem-sync Skill — Vertical 2 Spec

**Date:** 2026-04-30
**Status:** Approved

---

## Overview

`df-sync` is a bash script that keeps the DevFlow graph memory current after every commit and branch switch. It runs automatically via git hooks installed by `df-init`. `mem-sync` is a companion AI skill that agents invoke to verify memory is current before reading it.

This is Vertical 2. It builds on the `.devflow/` layout, lock protocol, atomic writes, and hook infrastructure established in Vertical 1.

---

## Entry Points

```bash
df-sync                 # re-sync current branch from last_synced SHA to HEAD
df-sync --branch-switch # called by post-checkout hook when $3 == 1
df-sync --force         # re-sync from scratch (ignores last_synced), subject to max_files_per_sync cap
df-sync --force --all   # re-sync from scratch, no file count cap (full repo import)
df-sync --version       # print version and exit 0
```

The post-commit hook calls `df-sync`. The post-checkout hook calls `df-sync --branch-switch` (guarded by `[ "$3" = "1" ] || exit 0`).

---

## Architecture

Single script: `bin/df-sync`. No shared libraries. All modes in one file.

**Internal function sections:**

| Function | Responsibility |
|---|---|
| `cmd_sync` | Post-commit path — diff → classify → static edges → AI batch → patch → finalize |
| `cmd_branch_switch` | Branch-switch path — swap symlink → bootstrap → conflict detection → cleanup → sync |
| `classify_file` | Heuristic glob classifier using `config.json classifiers`; AI fallback |
| `static_edges` | Language-specific regex import/using parser |
| `ai_batch` | Batches files into groups of 20, calls Claude API for intent + semantic edges |
| `patch_nodes` | Merges AI results into nodes.json, preserves `confidence:"manual"` |
| `patch_edges` | Merges static + AI edges into edges.json, deduplicates |
| `render_memory_md` | Regenerates memory.md from nodes.json + edges.json + memory.json |
| `staleness_sweep` | Marks nodes/edges stale by hard (deleted) or soft (age) criteria |
| `prune_graph` | Removes oldest stale nodes when graph_limits.max_nodes exceeded |

---

## Post-Commit Path (`cmd_sync`)

### Step 1: Prereqs + guard

1. `check_prereqs`: verify git repo, `jq` installed, `.devflow/` exists
2. CI mode: if no `.devflow/` → exit 0 silently
3. Acquire lock on `.devflow/sync.lock` via `flock` (non-blocking try-lock); if already locked → log `[DevFlow] sync already running — skipping`, exit 0. PID-file fallback on systems without `flock`.
4. Read `config.json` → extract `last_synced`, `classifiers`, `graph_limits`, `edge_staleness_threshold`, `no_intent_recheck`
5. Set `dirty: true` in `config.json` before any writes

### Step 2: Get changed files

- `--force` or `last_synced` is empty/null: changed files = all files from `git ls-files`
- Normal: `git diff --name-only <last_synced>..HEAD` → list of changed paths
- Deleted files (present in `last_synced` tree but absent in HEAD): collected separately as "deleted set" via `git diff --name-only --diff-filter=D <last_synced>..HEAD`
- If `git diff` fails (e.g., invalid SHA): exit 1 with `[DevFlow] git diff failed`

**Large repo cap:**

After collecting changed files, if count > `graph_limits.max_files_per_sync` (default: 200):

1. Sort by priority: routes first, then entities, then services, then contracts, then others
2. Take the top `max_files_per_sync` files
3. Log: `[DevFlow] Large sync: <N> files changed, capped at <max_files_per_sync> — run df-sync --force --all to process all files`
4. The `--all` flag bypasses the cap entirely (processes all changed files regardless of count)

This cap applies to both normal and `--force` mode. `--force --all` is the escape hatch for initial import of large repos.

### Step 3: Per-file — classify + static edges

For each changed file (excluding deleted set):

**classify_file `$path`:**
- Read `classifiers` array from `config.json`
- Run bash `case` glob match (same pattern as df-init: `*` matches `/`)
- If match found → return type
- If no match → AI fallback: send path + first 10 lines to Claude, get `{type, pattern}`. Write `pattern` back to `config.json classifiers`. Return type.
- `architecture` and `conventions` files are classified but their type is `architecture`/`conventions` (not added to the graph as nodes — they inform memory.json only)

**static_edges `$path`:**
- C# (`.cs` files): scan for `using <Namespace>;` lines at file top. For each, emit:
  ```json
  {"from": "<node_id>", "to_path": "<Namespace>", "rel": "uses", "source": "static"}
  ```
- TypeScript/Svelte (`.ts`, `.svelte`, `.svelte.ts`): scan for `import ... from '<path>'` statements. For each relative import (`./` or `../`), resolve to absolute path, emit:
  ```json
  {"from": "<node_id>", "to_path": "<resolved_path>", "rel": "uses", "source": "static"}
  ```
  Ignore package imports (no `./` or `../`).
- Unknown extension: return empty array.
- If file not found (race condition after deletion): return empty array.
- `architecture` and `conventions` type files: skip `static_edges` (these files inform memory.json, not graph nodes).

`to_path` values in static edges are resolved at `patch_edges` time to node IDs using the same ID formula as df-init (replace `/` with `.`, strip last extension, prepend type).

### Step 4: Staleness sweep (`staleness_sweep`)

Run after collecting changed files, before AI batch:

- **Hard stale:** for each path in deleted set → find node in `nodes.json` by `path` field → set `stale: true`
- **Soft stale:** for each node in `nodes.json` where `stale: false`:
  - Run `git log --follow --oneline -- <node.path>` and count commits since the node's `last_seen` SHA
  - If count ≥ `edge_staleness_threshold` → set `stale: true`
- **Edge staleness:** for each edge in `edges.json` — if either endpoint node is `stale: true` → set edge `stale: true`

### Step 5: AI batch (`ai_batch`)

Collect files needing intent inference:
- New nodes (not in existing `nodes.json`)
- Nodes whose file changed by >30 lines (`git diff --stat <last_synced>..HEAD -- <path>`)
- Exclude paths matching any pattern in `no_intent_recheck` config list. `no_intent_recheck` is an array of glob patterns in `config.json` (e.g., `["**/migrations/**", "**/*.generated.cs"]`) identifying files whose intent should never be re-inferred (generated files, migrations, etc.).

Group into batches of 20. For each batch, call Claude API:

**Prompt (per batch):**
```
You are analyzing source files for a <stack_runtime> + <stack_frontend> project.

For each file, return a JSON array where each element has:
- "path": the file path
- "intent": one sentence describing what this unit does
- "confidence": "ai"
- "edges": array of {to_file, rel, intent} for semantic relationships

rel values: depends_on, uses, persisted_in, implements, emits, handles

Files:
[{path, type, content (first 50 lines)}, ...]
```

**Response handling:**
- Parse JSON array
- On timeout: wait 5s, retry once
- On second timeout: for affected files, write node with `intent: ""`, `confidence: "ai"`, log `[DevFlow] AI batch timed out — writing nodes without intent`
- Continue sync regardless

**Pattern learning:**
- For any file that was AI-classified (no glob matched in `classify_file`), write the returned `pattern` to `config.json classifiers` array

### Step 6: patch_nodes + patch_edges

**patch_nodes:**
- For each node in AI response: upsert into `nodes.json` by `id`
- Preserve any existing node where `confidence: "manual"` — do not overwrite
- Set `last_seen` to current HEAD SHA on any updated node

**patch_edges:**
- Merge static edges + AI edges into `edges.json`
- Deduplicate by `(from, to, rel)` — `source: "static"` wins over `source: "ai"` on same key
- `to_path` → `to` node ID: apply ID formula; if target node doesn't exist in nodes.json, skip edge (dangling edge)

### Step 7: Finalize

1. `prune_graph`: if `nodes.json` count > `graph_limits.max_nodes` → remove oldest stale nodes (by `last_seen` SHA) until under limit. Also remove their associated edges.
2. `render_memory_md`: regenerate `.devflow/branches/<canon>/memory.md` (same format as df-init)
3. Atomic write `config.json` with `dirty: false` and `last_synced: <HEAD SHA>`
4. Release lock

---

## Branch-Switch Path (`cmd_branch_switch`)

Called by post-checkout hook with args: `$1` = prev HEAD SHA, `$2` = new HEAD SHA, `$3` = 1 (branch switch).

### Step 1: Read context

- `new_branch = git rev-parse --abbrev-ref HEAD`
- `prev_branch_sha = $1` (the SHA before checkout)
- `new_branch_canon = canonicalize(new_branch)` (replace `/` with `__`)

### Step 2: Swap active symlink

```bash
ln -sfn "branches/${new_branch_canon}" ".devflow/active"
mkdir -p ".devflow/branches/${new_branch_canon}"
```

### Step 3: Bootstrap new branch (if no existing memory)

If `.devflow/branches/<new_branch_canon>/memory.json` does not exist:

1. Find "nearest" branch = branch whose `git merge-base <branch> HEAD` is most recent (closest SHA to HEAD by commit count). Tie-break: prefer the branch with more nodes in its `nodes.json` (richer memory).
2. Copy that branch's memory: `cp -r ".devflow/branches/<nearest>/." ".devflow/branches/<new_branch_canon>/"`
3. Record `divergence_sha = git merge-base <nearest_branch> HEAD`
4. Update `config.json` for the new branch with `last_synced: <divergence_sha>`
5. `cmd_sync` will run in Step 6 and patch forward from `divergence_sha` to HEAD

If no other branches exist: initialize empty nodes.json + edges.json (schema_version 1, empty arrays).

### Step 4: Conflict detection

```
merge_base_sha = git merge-base <prev_branch_sha> HEAD
```

Compare nodes from the new branch's `nodes.json` against the prev branch's `nodes.json`:

- **intent conflict:** same node `id` exists in both, `intent` differs, neither is empty → flag
- **New nodes** in incoming branch: auto-add, no conflict
- **Nodes only in prev branch:** auto-keep, no conflict
- **`stale` differences:** ignored — staleness sweep will re-evaluate from HEAD
- **Edge conflicts:** not flagged (structural differences silently merged)

If conflicts found, write `.devflow/active/graph_conflicts.json`:
```json
{
  "generated_at": "<HEAD SHA>",
  "nodes": [
    {
      "id": "entity:Entities.Comment",
      "conflict": "intent",
      "branch_a": "Handles comment creation and validation",
      "branch_b": "Represents a reader comment on a story"
    }
  ],
  "edges": []
}
```

If no conflicts: delete `graph_conflicts.json` if it exists.

### Step 5: Stale branch cleanup

```bash
git branch --format='%(refname:short)' | sed 's|/|__|g'  # canonicalized local branch names
```

For each directory in `.devflow/branches/`: if canonicalized name has no matching local git branch → `rm -rf ".devflow/branches/<canon>"`.

### Step 6: Sync new branch

Call `cmd_sync` (normal mode, using the new branch's `last_synced`). This patches forward any commits on the new branch since it was last synced.

---

## Atomic Writes + Lock Protocol

Same protocol as df-init (Vertical 1):

- `dirty: true` set in `config.json` at start of any write operation
- All file writes: `printf '%s' "$content" > "$file.tmp" && sync && mv "$file.tmp" "$file"`
- `dirty: false` written only after all files validated (exist + valid JSON)
- Lock: `.devflow/sync.lock` via `flock -n` (non-blocking); PID-file fallback on macOS
- Lock released on EXIT trap

---

## AI Mock Mode

`DEVFLOW_AI_MOCK=1`: instead of calling Claude API, read from `tests/fixtures/ai-responses/df-sync-response.json`.

Fixture shape:
```json
{
  "batch": [
    {
      "path": "Entities/Comment.cs",
      "intent": "Represents a reader comment on a story",
      "confidence": "ai",
      "edges": [
        {"to_file": "Services/CommentService.cs", "rel": "uses", "intent": "comment data is processed by"}
      ]
    }
  ]
}
```

The same fixture is returned for every batch call in mock mode.

---

## mem-sync Skill (`skills/mem-sync/SKILL.md`)

A 4-step AI skill agents invoke before reading graph memory.

**Step 1: Check staleness**
- Read `.devflow/config.json`
- Get `last_synced` SHA and `dirty` flag
- Run `git rev-parse HEAD` → current HEAD SHA
- If `last_synced == HEAD` and `dirty == false` → memory is current, exit (nothing to do)

**Step 2: Run df-sync**
- Run `df-sync` on current branch
- If exit code non-zero → proceed to Step 4

**Step 3: Verify**
- Confirm all required files exist and are valid JSON:
  - `.devflow/active/memory.json`
  - `.devflow/active/nodes.json`
  - `.devflow/active/edges.json`
  - `.devflow/active/memory.md`
- Confirm `config.json` has `dirty: false` and `last_synced == HEAD`

**Step 4: Retry or fail**
- If Step 3 fails → run `df-sync` once more
- If still failing → log `[DevFlow] sync failed — memory may be stale` and exit 1

---

## Error Reference

| Scenario | Behavior |
|---|---|
| Not a git repo | Exit 1, `[DevFlow] Not a git repo` |
| No `.devflow/` | Exit 0 silently (CI mode) |
| `jq` not installed | Exit 1, `[DevFlow] Missing prerequisite: jq` |
| Lock held | Exit 0, `[DevFlow] sync already running — skipping` |
| `git diff` fails | Exit 1, `[DevFlow] git diff failed` |
| AI timeout (1st) | Wait 5s, retry |
| AI timeout (2nd) | Write without intent, `confidence:"ai"`, log warning, continue |
| Classifier glob error | Skip file, log warning, continue |
| Deleted file static parse | Skip (no content), return empty edges |
| Write failure | `dirty:true` survives, exit 1 |
| Dangling edge (unknown to_path) | Skip edge silently |

---

## Testing (`tests/df-sync.bats`)

**Fixtures:**
- `tests/fixtures/sample-repo/` (same as Vertical 1)
- `tests/fixtures/ai-responses/df-sync-response.json` (mock AI batch response)

**Test cases:**

| Test | Description |
|---|---|
| `--version` | Prints version, exits 0 |
| post-commit: node created | Changed file gets node in nodes.json with intent (mock mode) |
| post-commit: static C# edges | `using` directives parsed into edges |
| post-commit: static TS edges | `import` statements parsed into edges |
| post-commit: deleted file stale | Deleted file node marked `stale:true` |
| post-commit: last_synced updated | `config.json` has `last_synced == HEAD SHA` after sync |
| post-commit: memory.md regenerated | memory.md exists and contains node names |
| post-commit: dirty protocol | `dirty:true` set before writes, `dirty:false` after success |
| post-commit: `--force` | All files re-synced, last_synced reset |
| post-commit: concurrent lock | Second df-sync exits 0 with "sync already running" message |
| post-commit: AI mock mode | `DEVFLOW_AI_MOCK=1` uses fixture, no real API call |
| post-commit: AI timeout fallback | Node written without intent when AI fails |
| post-commit: pattern learning | AI-classified node writes pattern to `config.json classifiers` |
| post-commit: manual node preserved | Node with `confidence:"manual"` not overwritten |
| branch-switch: symlink swapped | `active` symlink points to new branch |
| branch-switch: new branch bootstrap | Memory copied from nearest branch |
| branch-switch: conflict detection | `graph_conflicts.json` written when intents differ |
| branch-switch: no conflicts | `graph_conflicts.json` absent when intents match |
| branch-switch: stale cleanup | Deleted branch's `.devflow/branches/<canon>/` removed |
| CI mode | No `.devflow/` → exit 0 silently |
| `--force` from scratch | nodes.json populated from all repo files |
| large repo cap | >200 changed files → capped at 200, warning logged, priority ordering applied |
| `--force --all` bypasses cap | All files processed regardless of count |
| not a git repo | Exit 1 with correct message |

---

## File Layout (additions to Vertical 1)

```
bin/
  df-sync                     # new script
skills/
  mem-sync/
    SKILL.md                  # new skill
tests/
  df-sync.bats                # new test file
  fixtures/
    ai-responses/
      df-sync-response.json   # new AI mock fixture
```

---

## Definition of Done

- [ ] `bin/df-sync` passes `shellcheck`
- [ ] `tests/df-sync.bats`: all tests pass
- [ ] `DEVFLOW_AI_MOCK=1` passes
- [ ] `skills/mem-sync/SKILL.md` written and quality-reviewed
- [ ] Works end-to-end: make a commit in the Ovell repo, verify nodes.json + memory.md updated
- [ ] Works end-to-end: switch branches in the Ovell repo, verify active symlink + conflict detection

---

## Out of Scope (deferred)

- `df-explain` command
- `df-resolve` command (conflict resolution UI)
- `df-workspace` and `df-export`
- Parallel execution / slice DAG
- Any frontend or UI

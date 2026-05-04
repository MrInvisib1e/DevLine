# Plan 6: Memory & Init Improvements

**Status:** Ready  
**Depends on:** none  
**Estimated tasks:** 9  
**Execute before:** Plan 1, 2, 3, 5, 4

## Context

This plan replaces the flat JSON graph store (`nodes.json` / `edges.json`) with SQLite as the primary store, adds tree-sitter AST extraction to replace regex classifiers in `df-sync`, and implements PageRank-ranked context generation in `df-explain`. It also overhauls the `init` skill to require only one user gate by auto-classifying all unambiguous file types silently.

## Pre-flight

- [ ] `sqlite3` is available on PATH: `sqlite3 --version`
- [ ] `bats` is available on PATH: `bats --version`
- [ ] Current test suite passes cleanly: `bats tests/df-sync.bats tests/df-init.bats tests/df-explain.bats`
- [ ] `.devflow/branches/main/nodes.json` and `edges.json` exist and are valid JSON
- [ ] No uncommitted changes in `bin/` or `skills/`: `git status --porcelain`

## Tasks

### Task 6.1 — Introduce SQLite graph store

**File(s):**
- Create: `bin/df-migrate`
- Modify: `bin/df-init` — `cmd_write_memory` section (lines ~279–384)
- Modify: `bin/df-sync` — node/edge loading (lines ~566–570), writes (lines ~667–674)
- Schema lives in: `.devflow/graph.db` (created at runtime, not committed)

**What:**
Create the `graph.db` schema and `df-migrate` script. Modify `df-init --write-memory` and `df-sync` so all node/edge reads and writes go to `graph.db` as the primary store. Keep `nodes.json` / `edges.json` as on-demand human-readable exports only.

Schema DDL:
```sql
CREATE TABLE IF NOT EXISTS nodes (
  id      TEXT PRIMARY KEY,
  kind    TEXT NOT NULL,
  name    TEXT NOT NULL,
  file_id TEXT NOT NULL,
  line    INTEGER DEFAULT 0,
  col     INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS edges (
  source     TEXT NOT NULL,
  target     TEXT NOT NULL,
  kind       TEXT NOT NULL,
  confidence REAL NOT NULL DEFAULT 0.7,
  PRIMARY KEY (source, target, kind)
);

CREATE INDEX IF NOT EXISTS idx_edges_target ON edges(target);
CREATE INDEX IF NOT EXISTS idx_nodes_name   ON nodes(name);
CREATE INDEX IF NOT EXISTS idx_nodes_file   ON nodes(file_id);

PRAGMA journal_mode=WAL;
```

In `bin/df-init --write-memory`: after creating `$branch_dir`, call `ensure_graph_db` (new helper) which runs the DDL if `graph.db` does not exist, then auto-calls `df-migrate` if `nodes.json` exists but `graph.db` does not.

In `bin/df-sync _do_sync`: replace `jq '.nodes // []' nodes.json` with SQLite SELECT; replace all `atomic_write nodes.json` / `atomic_write edges.json` with SQLite upserts.

**Why:** jq-based JSON manipulation is O(n²) in the staleness sweep loop — df-sync runs one `git log` call per node (line ~414). SQLite gives indexed access and WAL mode for safe concurrent hook usage.

**Verify:**
```bash
sqlite3 .devflow/graph.db "SELECT COUNT(*) FROM nodes;"  # > 0
sqlite3 .devflow/graph.db "PRAGMA journal_mode;"          # wal
bats tests/df-sync.bats
bats tests/df-init.bats
```

---

### Task 6.2 — Add content-hash caching

**File(s):**
- Modify: `bin/df-sync` — `_do_sync` per-file loop (lines ~574–595)
- Creates at runtime: `.devflow/cache/content-hashes.json`

**What:**
Add a cache layer keyed by file content hashes. Two levels:

- **Level 1 (`content_hash`):** SHA-256 of full file content (`sha256sum` on Linux, `shasum -a 256` on macOS). Skip the file entirely if unchanged.
- **Level 2 (`api_hash`):** SHA-256 of exported symbols only. Populated by tree-sitter in Task 6.4; defaults to `content_hash` until then.

Cache schema (`.devflow/cache/content-hashes.json`):
```json
{
  "src/routes/CommentController.svelte": {
    "content_hash": "sha256:abc123",
    "api_hash":     "sha256:def456",
    "last_synced":  "<git-sha>"
  }
}
```

Add helpers to `bin/df-sync`:
```bash
file_content_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

is_cache_hit() {
  local stored
  stored=$(jq -r --arg f "$1" '.[$f].content_hash // ""' \
    "${DEVFLOW_DIR}/cache/content-hashes.json")
  [[ -n "$stored" && "$stored" = "$(file_content_hash "$1")" ]]
}
```

In the per-file loop: `is_cache_hit "$f" && continue` before processing; `update_cache_entry "$f" "$head_sha"` after.

**Why:** Most files don't change between commits. Skipping unchanged files avoids redundant AI classification calls and static analysis passes on every post-commit hook run.

**Verify:**
```bash
time df-sync          # first run: processes all files
time df-sync          # second run: should be significantly faster (cache hits)
jq 'keys | length' .devflow/cache/content-hashes.json  # > 0
bats tests/df-sync.bats
```

---

### Task 6.3 — Add quick sync mode to df-sync

**File(s):**
- Modify: `bin/df-sync` — `cmd_sync` function, `_do_sync` signature
- Modify: `bin/df-init` — `install_hook` calls (lines ~364–368)

**What:**
Add `--quick` flag to `df-sync`. In quick mode: skip `ai_batch` entirely (`ai_results="[]"`), do tree-sitter AST extraction only, write EXTRACTED edges to SQLite with `confidence=1.0`.

```bash
cmd_sync() {
  local force=false all_flag=false quick=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)        force=true; shift ;;
      --all)          all_flag=true; shift ;;
      --quick)        quick=true; shift ;;
      --branch-switch) shift; cmd_branch_switch; return ;;
      *) shift ;;
    esac
  done
  check_prereqs
  [[ ! -d "$DEVFLOW_DIR" ]] && exit 0
  acquire_lock
  _do_sync "$force" "$all_flag" "$quick"
}
```

In `_do_sync`, wrap AI call:
```bash
if [[ "$quick" != "true" ]]; then
  ai_results=$(ai_batch)
else
  ai_results="[]"
fi
```

Update git hooks in `cmd_write_memory`:
```bash
install_hook "${hooks_dir}/post-commit" "df-sync --quick"
install_hook "${hooks_dir}/post-checkout" \
  '[ "$3" = "1" ] || exit 0; df-sync --quick --branch-switch'
```

Performance target (document in script header): `<100ms` for <200 files, `<500ms` for <2000 files.

**Why:** The post-commit hook fires on every commit. Full sync blocks developer workflow. Quick mode keeps the graph structurally accurate; AI enrichment happens on explicit calls.

**Verify:**
```bash
grep 'df-sync --quick' .git/hooks/post-commit
time df-sync --quick   # should complete in <500ms on this repo
bats tests/df-sync.bats
```

---

### Task 6.4 — Replace regex classifiers with tree-sitter extraction

**File(s):**
- Modify: `bin/df-sync` — `static_edges` function (lines ~147–190)
- Create: `bin/lib/ts-extract`

**What:**
Replace bash regex import-matching in `static_edges` with a call to `bin/lib/ts-extract`.

`bin/lib/ts-extract` specification:
- Args: `<file-path>`
- Uses `npx tree-sitter` if Node is on PATH; falls back to existing regex if unavailable
- Outputs newline-delimited JSON: `{"kind":"EXTRACTED","source":"<file>","target":"<path>","edge_kind":"uses","confidence":1.0}`

Language map (associative array in script):
```bash
declare -A TS_GRAMMAR
TS_GRAMMAR=(
  [ts]="typescript"  [tsx]="typescript"
  [js]="javascript"  [jsx]="javascript"
  [svelte]="svelte"  [cs]="c_sharp"
  [py]="python"      [go]="go"
  [rs]="rust"        [java]="java"
  [rb]="ruby"        [kt]="kotlin"
  [swift]="swift"    [php]="php"
  [lua]="lua"        [scala]="scala"
  [ex]="elixir"      [exs]="elixir"
  [dart]="dart"      [vue]="vue"
  [cpp]="cpp"        [cc]="cpp"  [cxx]="cpp"  [c]="c"
)
```

For each file: detect grammar → run `npx --yes tree-sitter parse --quiet "$file"` → extract import/call nodes → emit JSON. Fall back to regex on error.

In `bin/df-sync`, update `static_edges` to call `ts-extract`, pipe output through jq to build edges JSON, fall back to original regex block if binary not found.

Add `confidence` field threading through `patch_edges` and SQLite upserts:
`INSERT OR REPLACE INTO edges(source, target, kind, confidence) VALUES(?,?,?,?)`

**Why:** Regex misses re-exports, dynamic imports, barrel files, and multi-line expressions. Tree-sitter parses actual AST, giving deterministic extraction for 25+ languages with graceful fallback.

**Verify:**
```bash
bin/lib/ts-extract src/some-typescript-file.ts
# Should output JSON lines with confidence=1.0 for import statements
sqlite3 .devflow/graph.db "SELECT source, target, confidence FROM edges LIMIT 5;"
bats tests/df-sync.bats
```

---

### Task 6.5 — Implement PageRank-ranked context in df-explain

**File(s):**
- Modify: `bin/df-explain` — add `cmd_rank`, update dispatch block

**New flags:** `--rank`, `--diff <sha1> <sha2>`, `--budget <tokens>`

**What:**
Add `cmd_rank` function using SQLite-based PageRank (10 iterations, damping=0.85):

```bash
_pagerank_sqlite() {
  local db="$1" iters="${2:-10}" d="${3:-0.85}"
  sqlite3 "$db" <<'SQL'
DROP TABLE IF EXISTS _pr_curr;
CREATE TEMP TABLE _pr_curr AS
  SELECT id, 1.0/(SELECT COUNT(*) FROM nodes) AS rank FROM nodes;
CREATE TEMP TABLE _out_degree AS
  SELECT source AS id, COUNT(*) AS deg FROM edges GROUP BY source;
SQL
  local i=0
  while [[ $i -lt $iters ]]; do
    sqlite3 "$db" <<SQL
CREATE TEMP TABLE _pr_next AS
  SELECT n.id,
    (1.0 - ${d})/(SELECT COUNT(*) FROM nodes)
    + ${d} * COALESCE((
        SELECT SUM(pr.rank / COALESCE(od.deg,1))
        FROM edges e
        JOIN _pr_curr pr ON pr.id = e.source
        LEFT JOIN _out_degree od ON od.id = e.source
        WHERE e.target = n.id), 0) AS rank
  FROM nodes n;
DROP TABLE _pr_curr;
ALTER TABLE _pr_next RENAME TO _pr_curr;
SQL
    ((i++)) || true
  done
  sqlite3 "$db" \
    "SELECT id, kind, file_id, rank FROM _pr_curr ORDER BY rank DESC;"
}
```

Dynamic token budget: `DEVFLOW_CONTEXT_FILES` set → 512; no context → 2048; `--budget` flag overrides.

`--diff <sha1> <sha2>`: compare node/edge sets between two git SHAs using `git show <sha>:.devflow/active/nodes.json`, report added/removed/changed.

Update dispatch: if no `INPUT` and no `--node` arg, default to `cmd_rank` with default budget instead of printing usage error.

**Why:** BFS from a single node answers "what does X depend on?" but gives no guidance about which nodes are most central. PageRank surfaces the highest-leverage nodes for context loading — skills that call `df-explain` with no specific file get the most important nodes first.

**Verify:**
```bash
df-explain --rank           # ranked list, not usage error
df-explain --rank --budget 512
df-explain --diff HEAD~5 HEAD
df-explain                  # should default to rank mode
bats tests/df-explain.bats
```

---

### Task 6.6 — Zero-question init (skill rewrite)

**File(s):**
- Modify: `skills/init/SKILL.md`

**What:**
Rewrite Steps 2–5 of the init skill to be T1 Silent or T2 Inform. The binary (`bin/df-init`) has no interactive prompts — this task is the AI skill wrapper only.

**Remove entirely:**
- Step 2: Y/N stack confirmation gate
- Step 3: workspace name A/B choice gate  
- Step 4: custom node types A/B gate
- Step 5: unclassified file batch-review loop

**Replace with expanded auto-classifiers (T1 Silent):**
```
*.test.*, *.spec.*, __tests__/**         → test
*.config.*, *.env*, tsconfig*, vite.*    → config
*.md, *.mdx, docs/**                     → docs
Dockerfile, docker-compose*, .github/**  → infra
*.sql, migrations/**                     → data
package.json, *.lock, go.mod, Cargo.toml → deps
bin/**, scripts/**, Makefile, *.sh       → script
[everything else]                        → source (not "unknown")
```

**Stack detection (T1 Silent):**
```
package.json → nodejs; + vite.config → sveltekit; + next.config → nextjs
*.csproj / *.sln → dotnet-9
requirements.txt / pyproject.toml → python
go.mod → go; Cargo.toml → rust; Gemfile → ruby
Workspace name: git remote URL → repo name; fallback: directory name
```

**New Step 2 (T2 Inform, no wait):**
```
Print: "[DevFlow] Detected: <runtime> + <frontend>. Workspace: <name>."
Print: "[DevFlow] Classified N files automatically."
Continue immediately.
```

**New Step 3 (T3 Gate — the only remaining gate):**
```
[DevFlow] Ready to initialize. Here's what I'll write:

  Workspace:  <name>
  Runtime:    <runtime>
  Frontend:   <frontend>
  Test cmd:   <test_cmd>
  Nodes:      N (<counts by type>)
  Branch:     <branch>

  Proceed? [Y / tell me what to change]
```

If Y: write memory. If changes: apply and re-present.

**Updated Guard Rails:**
```markdown
1. One gate only — the final summary. Never add gates before it.
2. T1 for derivable decisions. Stack, workspace, file classification — T1 Silent.
3. T2 for inferences. Print stack detection result; do not ask for pre-confirmation.
4. Merge, not overwrite. Re-init merges existing confidence:"manual" nodes.
5. Reality check. Don't reclassify correctly classified nodes.
```

**Why:** The current skill fires 4 gates before writing a single byte. All 4 ask for confirmation of data either derivable from the filesystem or correctable at the final gate.

**Verify:**
```bash
grep -c "Wait for\|Is this correct\|\[Y\] Yes\|\[A\]\|\[B\]" skills/init/SKILL.md
# Expected: 1 (the "Proceed?" final gate)
grep "Proceed?" skills/init/SKILL.md
grep "_shared.md" skills/init/SKILL.md
```

---

### Task 6.7 — Update memory.md rendering to tiered format

**File(s):**
- Modify: `bin/df-sync` — `render_memory_md` function (lines ~194–257)
- Modify: `bin/df-init` — `render_memory_md` function (lines ~205–256)

**What:**
Replace flat node-list rendering with 3-section tiered format capped at 2,500 tokens.

Target structure:
```markdown
# DevFlow Memory
<!-- Generated: <sha> | Nodes: N | Edges: M -->

## Stack
- Runtime: <runtime>
- Frontend: <frontend>

## Top Nodes by PageRank
<top 30-50 nodes, 20 tokens each, capped at 2000 tokens>
<node_id> [<kind>] <file_id>

## Edge Summary
EXTRACTED: N  INFERRED: M  AMBIGUOUS: K

## Drill-down
Run `df-explain --rank` for full ranked graph.
Run `df-explain <node-id>` for a specific node.
Run `df-explain --diff HEAD~5 HEAD` to see recent changes.
```

Token budget: Stack ~50T always; Top Nodes up to 2000T (stop when budget reached); Edge Summary ~100T; Drill-down ~100T. Hard cap: 2,500T total.

In `render_memory_md`: if `graph.db` exists, use `ORDER BY COUNT(e.source) DESC LIMIT 50` as PageRank proxy; else fall back to `nodes.json` sorted by type priority.

**Why:** Current rendering dumps all nodes with no cap. 500+ node repos produce memory.md files that overflow LLM context windows.

**Verify:**
```bash
echo "$(wc -w < .devflow/active/memory.md) / 0.75" | bc  # should be <2500
grep '## Top Nodes' .devflow/active/memory.md
grep '## Edge Summary' .devflow/active/memory.md
grep 'df-explain --rank' .devflow/active/memory.md
bats tests/df-sync.bats
```

---

### Task 6.8 — Batch git log for staleness detection

**File(s):**
- Modify: `bin/df-sync` — `staleness_sweep` function (lines ~393–455)

**What:**
Replace per-node `git log` calls with a single batch call.

Current (O(n) git subprocesses):
```bash
# line ~425, inside per-node loop:
commit_count=$(git log --oneline "${node_last_seen}..HEAD" -- "$node_file" | wc -l)
```

New (one call for all files):
```bash
_batch_changed_files() {
  local oldest_sha="$1"
  [[ -z "$oldest_sha" ]] && echo '{}' && return
  git log --name-only --pretty=format:'' "${oldest_sha}..HEAD" 2>/dev/null |
    grep -v '^$' | sort | uniq -c |
    awk '{print $2 "\t" $1}' |
    jq -Rn '[inputs | split("\t") | {(.[0]): (.[1]|tonumber)}] | add // {}'
}
```

Before the loop: `changed_map=$(_batch_changed_files "$oldest_sha")`  
In the loop: `commit_count=$(printf '%s' "$changed_map" | jq -r --arg f "$node_file" '.[$f] // 0')`

Also add reverse BFS for transitive dependency detection (via SQLite recursive CTE):
```sql
WITH RECURSIVE affected(id) AS (
  SELECT id FROM nodes WHERE file_id IN (<changed_file_ids>)
  UNION
  SELECT e.source FROM edges e JOIN affected a ON a.id = e.target
)
SELECT DISTINCT id FROM affected;
```

**Why:** 500 nodes = 500 git subprocess forks per sync. Single batch call reduces this to ~200ms regardless of node count.

**Verify:**
```bash
time df-sync --force  # measure with many changed files
sqlite3 .devflow/graph.db "SELECT COUNT(*) FROM nodes WHERE kind='aged';"
bats tests/df-sync.bats
```

---

### Task 6.9 — Write df-migrate script

**File(s):**
- Create: `bin/df-migrate`

**What:**
Standalone migration script: reads `nodes.json` + `edges.json`, writes to `graph.db`. Idempotent (no-op if DB already populated), `--force` flag for re-migration.

Key behaviors:
1. Check `graph.db` doesn't exist or is empty; if populated, exit (unless `--force`)
2. Create schema (same DDL as Task 6.1)
3. Read nodes via `jq -c '.nodes[]'`, insert each with `INSERT OR IGNORE INTO nodes`
4. Read edges via `jq -c '.edges[]'`, insert each with `INSERT OR IGNORE INTO edges`
5. Verify: `SELECT COUNT(*) FROM nodes` matches `jq '.nodes | length' nodes.json`
6. Print: `[DevFlow] Migration complete: N nodes, M edges in graph.db`

Error cases:
- `nodes.json` not found → exit 1 with message
- `sqlite3` not available → exit 1 with install instructions
- Count mismatch after migration → exit 1 with mismatch details

**Why:** Migration must be a discrete, auditable step with clear output and count verification. Idempotent to enable safe re-runs.

**Verify:**
```bash
bin/df-migrate
# "[DevFlow] Migration complete: N nodes, M edges in graph.db"
db_count=$(sqlite3 .devflow/graph.db "SELECT COUNT(*) FROM nodes;")
json_count=$(jq '.nodes | length' .devflow/branches/main/nodes.json)
[[ "$db_count" -eq "$json_count" ]] && echo "MATCH"
bin/df-migrate  # second run: exits 0, "already has N nodes"
bats tests/df-sync.bats
```

---

## Verification Gates

After all tasks complete:

- [ ] `bats tests/df-sync.bats` — all pass
- [ ] `bats tests/df-init.bats` — all pass  
- [ ] `bats tests/df-explain.bats` — all pass
- [ ] Init skill has exactly 1 gate: `grep -c "Proceed?" skills/init/SKILL.md` = 1
- [ ] Quick sync under 500ms: `time df-sync --quick`
- [ ] `df-explain --rank` returns ranked list, not usage error
- [ ] `df-explain` with no args defaults to rank mode
- [ ] `graph.db` exists after init: `[[ -f .devflow/graph.db ]]`
- [ ] `df-migrate` count matches JSON: run verify step from Task 6.9
- [ ] `memory.md` under 2,500 tokens: word count / 0.75 < 2500
- [ ] Git hooks use `--quick`: `grep 'df-sync --quick' .git/hooks/post-commit`
- [ ] `ts-extract` falls back gracefully when `node` not on PATH

## Rollback

`nodes.json` / `edges.json` are untouched — SQLite is additive throughout.

```bash
rm -f .devflow/graph.db .devflow/cache/content-hashes.json
git checkout HEAD -- bin/df-sync bin/df-explain bin/df-init
rm -f bin/df-migrate bin/lib/ts-extract
git checkout HEAD -- skills/init/SKILL.md
# Manually restore hooks: edit .git/hooks/post-commit to remove --quick
```

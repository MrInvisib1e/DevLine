# df-explain + df-test + fix skill — Vertical 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `bin/df-explain` (graph BFS diagnostic tool), `bin/df-test` (slice test runner), and `skills/fix/SKILL.md` (memory-aware bug fix flow), all tested with bats and shellcheck.

**Architecture:** Two thin bash scripts following the exact patterns of `bin/df-init` and `bin/df-sync` — `set -euo pipefail`, `err()` helper, `atomic_write`, `check_prereqs`, jq for JSON. The fix skill is a SKILL.md markdown document read by the AI agent. No shared libraries — each script is self-contained.

**Tech Stack:** bash 5+, bats 1.13, jq 1.6+, git. Follows all patterns from `bin/df-init` and `bin/df-sync`.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `bin/df-explain` | Create | Node lookup + BFS traversal + human-readable report |
| `bin/df-test` | Create | Read slices.json, run test_cmd, write result back |
| `skills/fix/SKILL.md` | Create | 3-cycle AI bug-fix flow using df-explain + df-test |
| `tests/df-explain.bats` | Create | 19 bats tests for df-explain |
| `tests/df-test.bats` | Create | 11 bats tests for df-test |
| `tests/fixtures/sample-memory/` | Create | nodes.json + edges.json fixtures for df-explain tests |
| `tests/fixtures/sample-slices.json` | Create | slices.json fixture for df-test tests |

---

## Shared Context (read before every task)

**Repo:** `/Volumes/ReydoSSD/SourceCode/Development-Flow`

**Key patterns from df-init/df-sync to reuse:**
```bash
err() { echo "[DevFlow] $*" >&2; }

check_prereqs() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not a git repo."
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    err "Missing prerequisite: jq"
    exit 1
  fi
}

atomic_write() {
  local file="$1" content="$2"
  local tmp="${file}.tmp"
  if [[ -e "$file" && ! -w "$file" ]]; then return 1; fi
  printf '%s' "$content" > "$tmp"
  sync 2>/dev/null || true
  mv "$tmp" "$file"
}
```

**CI mode pattern:** Check for `.devflow/` after prereqs — if missing, exit 0 silently (df-explain and df-test both follow this).

**Version constant:** `DEVFLOW_VERSION="0.1.0"` — same in all scripts.

**Spec file:** `docs/superpowers/specs/2026-04-30-vertical-3-df-explain-df-test-fix-skill.md`

**Node ID format:** `<type>:<path-with-dots-last-ext-stripped>`
- `Entities/Comment.cs` → `entity:Entities.Comment`
- Strip LAST extension only

**nodes.json schema:**
```json
{
  "schema_version": 1,
  "nodes": [
    {
      "id": "entity:Entities.Comment",
      "type": "entity",
      "file": "Entities/Comment.cs",
      "intent": "Soft-deletable content unit attached to a story",
      "confidence": "high",
      "stale": false,
      "last_seen": "abc1234"
    }
  ]
}
```

**edges.json schema:**
```json
{
  "schema_version": 1,
  "edges": [
    {
      "from": "entity:Entities.Comment",
      "to": "service:Services.CommentService",
      "rel": "uses"
    }
  ]
}
```

**slices.json schema:**
```json
{
  "feature": "comments",
  "approved_at": "2026-04-30T10:00:00Z",
  "slices": [
    {
      "id": 1,
      "name": "User can create a comment",
      "layers": ["db", "service", "api", "frontend"],
      "result": "POST /api/comments returns 201",
      "test_cmd": "echo PASS",
      "depends_on": [],
      "status": "pending"
    }
  ]
}
```

---

## Task 1: Scaffolding + Fixtures

**Files:**
- Create: `bin/df-explain` (stub)
- Create: `bin/df-test` (stub)
- Create: `skills/fix/` (directory — empty, tracked via .gitkeep or first file)
- Create: `tests/fixtures/sample-memory/nodes.json`
- Create: `tests/fixtures/sample-memory/edges.json`
- Create: `tests/fixtures/sample-slices.json`
- Create: `tests/df-explain.bats` (placeholder)
- Create: `tests/df-test.bats` (placeholder)

- [ ] **Step 1: Create fixture nodes.json**

Create `tests/fixtures/sample-memory/nodes.json`:

```json
{
  "schema_version": 1,
  "nodes": [
    {
      "id": "entity:Entities.Comment",
      "type": "entity",
      "file": "Entities/Comment.cs",
      "intent": "Soft-deletable content unit attached to a story",
      "confidence": "high",
      "stale": false,
      "last_seen": "abc1234"
    },
    {
      "id": "service:Services.CommentService",
      "type": "service",
      "file": "Services/CommentService.cs",
      "intent": "Owns all comment mutations",
      "confidence": "high",
      "stale": false,
      "last_seen": "abc1234"
    },
    {
      "id": "route:src.routes.+page",
      "type": "route",
      "file": "src/routes/+page.svelte",
      "intent": "Home page route",
      "confidence": "ai",
      "stale": false,
      "last_seen": "abc1234"
    },
    {
      "id": "contract:Contracts.CommentCreatedEvent",
      "type": "contract",
      "file": "Contracts/CommentCreatedEvent.cs",
      "intent": "Event emitted when a new comment is created",
      "confidence": "ai",
      "stale": "aged",
      "last_seen": "def5678"
    },
    {
      "id": "service:Services.UserService",
      "type": "service",
      "file": "Services/UserService.cs",
      "intent": "Manages user accounts",
      "confidence": "high",
      "stale": false,
      "last_seen": "abc1234"
    }
  ]
}
```

- [ ] **Step 2: Create fixture edges.json**

Create `tests/fixtures/sample-memory/edges.json`:

```json
{
  "schema_version": 1,
  "edges": [
    {
      "from": "entity:Entities.Comment",
      "to": "service:Services.CommentService",
      "rel": "uses"
    },
    {
      "from": "service:Services.CommentService",
      "to": "contract:Contracts.CommentCreatedEvent",
      "rel": "emits"
    },
    {
      "from": "route:src.routes.+page",
      "to": "service:Services.CommentService",
      "rel": "uses"
    },
    {
      "from": "service:Services.UserService",
      "to": "entity:Entities.Comment",
      "rel": "uses"
    }
  ]
}
```

- [ ] **Step 3: Create fixture slices.json**

Create `tests/fixtures/sample-slices.json`:

```json
{
  "feature": "comments",
  "approved_at": "2026-04-30T10:00:00Z",
  "slices": [
    {
      "id": 1,
      "name": "User can create a comment",
      "layers": ["db", "service", "api", "frontend"],
      "result": "POST /api/comments returns 201",
      "test_cmd": "echo PASS_SLICE_1",
      "depends_on": [],
      "status": "pending"
    },
    {
      "id": 2,
      "name": "User can delete a comment",
      "layers": ["service", "api", "frontend"],
      "result": "DELETE /api/comments/:id returns 204",
      "test_cmd": "exit 1",
      "depends_on": [1],
      "status": "failed"
    },
    {
      "id": 3,
      "name": "User can list comments",
      "layers": ["service", "api", "frontend"],
      "result": "GET /api/stories/:id/comments returns list",
      "test_cmd": null,
      "depends_on": [],
      "status": "done"
    }
  ]
}
```

- [ ] **Step 4: Create bin/df-explain stub**

Create `bin/df-explain`:

```bash
#!/usr/bin/env bash
set -euo pipefail
echo "[DevFlow] df-explain stub — not yet implemented" >&2
exit 1
```

Make it executable: `chmod +x bin/df-explain`

- [ ] **Step 5: Create bin/df-test stub**

Create `bin/df-test`:

```bash
#!/usr/bin/env bash
set -euo pipefail
echo "[DevFlow] df-test stub — not yet implemented" >&2
exit 1
```

Make it executable: `chmod +x bin/df-test`

- [ ] **Step 6: Create placeholder bats files**

Create `tests/df-explain.bats`:

```bash
#!/usr/bin/env bats

@test "placeholder passes" {
  true
}
```

Create `tests/df-test.bats`:

```bash
#!/usr/bin/env bats

@test "placeholder passes" {
  true
}
```

Create `skills/fix/` directory placeholder (needed for git):

```bash
touch skills/fix/.gitkeep
```

- [ ] **Step 7: Run bats to verify scaffolding is correct**

```bash
bats tests/df-explain.bats tests/df-test.bats
```

Expected: `2 tests, 0 failures`

- [ ] **Step 8: Commit**

```bash
git add bin/df-explain bin/df-test skills/fix/.gitkeep \
  tests/df-explain.bats tests/df-test.bats \
  tests/fixtures/sample-memory/nodes.json \
  tests/fixtures/sample-memory/edges.json \
  tests/fixtures/sample-slices.json
git commit -m "chore: scaffold vertical-3 directories and fixtures"
```

---

## Task 2: Write Failing Tests (TDD Baseline)

**Files:**
- Modify: `tests/df-explain.bats`
- Modify: `tests/df-test.bats`

- [ ] **Step 1: Write full df-explain test suite**

Replace `tests/df-explain.bats` with:

```bash
#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────

setup() {
  export REPO
  REPO="$(mktemp -d)"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "initial" --quiet)
  # Install devflow memory structure
  mkdir -p "$REPO/.devflow/branches/main"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-memory/nodes.json" "$REPO/.devflow/branches/main/nodes.json"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-memory/edges.json" "$REPO/.devflow/branches/main/edges.json"
  ln -sfn "branches/main" "$REPO/.devflow/active"
  export DF_EXPLAIN="$BATS_TEST_DIRNAME/../bin/df-explain"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$REPO"
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "df-explain --version prints DevFlow version and exits 0" {
  run "$DF_EXPLAIN" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── name resolution ───────────────────────────────────────────────────────────

@test "exact match: entity:Entities.Comment resolves" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Comment" ]]
  [[ "$output" =~ "entity" ]]
}

@test "case-insensitive match: 'userservice' resolves to service:Services.UserService" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'userservice'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "UserService" ]]
}

@test "substring single match: 'CreatedEvent' resolves" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'CreatedEvent'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "CommentCreatedEvent" ]]
}

@test "substring multiple matches: lists options and exits 1" {
  # 'comment' matches entity:Entities.Comment AND service:Services.CommentService AND contract:Contracts.CommentCreatedEvent
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'comment' 2>&1 || true"
  # With multiple matches it should list them and exit 1
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Multiple matches" ]]
}

@test "file path match: Entities/Comment.cs resolves" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'Entities/Comment.cs'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Comment" ]]
}

@test "no match: prints no-memory message and exits 1" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'NonExistent' 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "No memory found" ]]
}

@test "--node exact: resolves exact node ID" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' --node 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Comment" ]]
}

@test "--node not found: prints error and exits 1" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' --node 'entity:Nonexistent' 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

# ─── BFS depth ─────────────────────────────────────────────────────────────────

@test "depth 0: node card only, no DEPENDS ON or DEPENDED ON BY" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' --depth 0 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "DEPENDS ON" ]]
  [[ ! "$output" =~ "DEPENDED ON BY" ]]
}

@test "depth 1 (default): shows direct neighbours" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DEPENDS ON" ]] || [[ "$output" =~ "DEPENDED ON BY" ]]
}

@test "depth cap: --depth 99 is silently capped at 5 and does not error" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' --depth 99 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
}

# ─── stale nodes ───────────────────────────────────────────────────────────────

@test "stale node shows [STALE] marker in output" {
  # contract:Contracts.CommentCreatedEvent has stale: "aged" in fixture
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'CommentCreatedEvent'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "STALE" ]]
}

# ─── edge display ──────────────────────────────────────────────────────────────

@test "node with no outbound edges omits DEPENDS ON section" {
  # service:Services.UserService has no outbound edges (it only has inbound from it to entity)
  # Actually UserService → Comment (uses), so it HAS outbound. Let's check a node with no inbound.
  # route:src.routes.+page has no inbound edges — DEPENDED ON BY omitted
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' --node 'route:src.routes.+page'"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "DEPENDED ON BY" ]]
}

@test "node with inbound edges shows DEPENDED ON BY section" {
  # entity:Entities.Comment is depended on by UserService (UserService → Comment)
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' --node 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DEPENDED ON BY" ]]
}

# ─── error paths ───────────────────────────────────────────────────────────────

@test "not a git repo: exits 1 with message" {
  tmpdir="$(mktemp -d)"
  run bash -c "cd '$tmpdir' && '$DF_EXPLAIN' Comment 2>&1 || true"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not a git repo" ]]
}

@test "no .devflow/: exits 0 silently (CI mode)" {
  tmpdir="$(mktemp -d)"
  (cd "$tmpdir" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "init" --quiet)
  run bash -c "cd '$tmpdir' && '$DF_EXPLAIN' Comment"
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "nodes.json missing: exits 1 with not-initialised message" {
  rm "$REPO/.devflow/branches/main/nodes.json"
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' Comment 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not initialised" ]] || [[ "$output" =~ "not initialized" ]]
}
```

- [ ] **Step 2: Write full df-test test suite**

Replace `tests/df-test.bats` with:

```bash
#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────

setup() {
  export REPO
  REPO="$(mktemp -d)"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "initial" --quiet)
  mkdir -p "$REPO/.devflow/branches/main"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-slices.json" "$REPO/.devflow/branches/main/slices.json"
  ln -sfn "branches/main" "$REPO/.devflow/active"
  export DF_TEST="$BATS_TEST_DIRNAME/../bin/df-test"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$REPO"
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "df-test --version prints DevFlow version and exits 0" {
  run "$DF_TEST" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── happy path ────────────────────────────────────────────────────────────────

@test "happy path PASS: runs test_cmd, prints PASS, exits 0" {
  # Slice 1 has test_cmd: "echo PASS_SLICE_1" which exits 0
  run bash -c "cd '$REPO' && '$DF_TEST' 1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PASS" ]]
}

@test "happy path FAIL: runs test_cmd, prints FAIL, exits non-zero" {
  # Slice 2 has test_cmd: "exit 1" which exits 1
  run bash -c "cd '$REPO' && '$DF_TEST' 2 2>&1 || true"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "FAIL" ]]
}

@test "exit code passthrough: FAIL exits with test command exit code" {
  run bash -c "cd '$REPO' && '$DF_TEST' 2; echo exit_was:\$?"
  [[ "$output" =~ "exit_was:1" ]]
}

@test "status written to slices.json: PASS sets status to done" {
  bash -c "cd '$REPO' && '$DF_TEST' 1" || true
  run bash -c "jq -r '.slices[] | select(.id==1) | .status' '$REPO/.devflow/branches/main/slices.json'"
  [ "$status" -eq 0 ]
  [ "$output" = "done" ]
}

@test "status written to slices.json: FAIL sets status to failed" {
  bash -c "cd '$REPO' && '$DF_TEST' 2" || true
  run bash -c "jq -r '.slices[] | select(.id==2) | .status' '$REPO/.devflow/branches/main/slices.json'"
  [ "$status" -eq 0 ]
  [ "$output" = "failed" ]
}

@test "--list: prints all slices with statuses" {
  run bash -c "cd '$REPO' && '$DF_TEST' --list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "comments" ]]
  [[ "$output" =~ "pending" ]]
  [[ "$output" =~ "failed" ]]
  [[ "$output" =~ "done" ]]
}

@test "DEVFLOW_TEST_CMD override: uses env var instead of slices.json test_cmd" {
  run bash -c "cd '$REPO' && DEVFLOW_TEST_CMD='echo OVERRIDDEN' '$DF_TEST' 1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "OVERRIDDEN" ]]
}

# ─── error paths ───────────────────────────────────────────────────────────────

@test "slice not found: exits 1 with message" {
  run bash -c "cd '$REPO' && '$DF_TEST' 999 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

@test "no test_cmd: exits 1 with message" {
  # Slice 3 has test_cmd: null
  run bash -c "cd '$REPO' && '$DF_TEST' 3 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "no test_cmd" ]] || [[ "$output" =~ "No test" ]]
}

@test "no slices.json and no DEVFLOW_TEST_CMD: exits 1 with message" {
  rm "$REPO/.devflow/branches/main/slices.json"
  run bash -c "cd '$REPO' && '$DF_TEST' 1 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "No slice plan" ]] || [[ "$output" =~ "slice plan" ]]
}

@test "not a git repo: exits 1 with message" {
  tmpdir="$(mktemp -d)"
  run bash -c "cd '$tmpdir' && '$DF_TEST' 1 2>&1 || true"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not a git repo" ]]
}
```

- [ ] **Step 3: Run bats to verify all tests fail (expected)**

```bash
bats tests/df-explain.bats tests/df-test.bats
```

Expected: all tests fail with stub exit 1 messages. No test should error due to syntax issues — only fail due to missing implementation.

- [ ] **Step 4: Commit**

```bash
git add tests/df-explain.bats tests/df-test.bats
git commit -m "test: add failing df-explain and df-test bats test suites (TDD baseline)"
```

---

## Task 3: Implement `bin/df-explain`

**Files:**
- Modify: `bin/df-explain`

- [ ] **Step 1: Write the full implementation**

Replace `bin/df-explain` with:

```bash
#!/usr/bin/env bash
# shellcheck enable=require-variable-braces
set -euo pipefail

# ─── constants ────────────────────────────────────────────────────────────────

DEVFLOW_VERSION="0.1.0"
MAX_DEPTH=5

# ─── helpers ──────────────────────────────────────────────────────────────────

err() { echo "[DevFlow] $*" >&2; }

check_prereqs() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not a git repo."
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    err "Missing prerequisite: jq"
    exit 1
  fi
}

# ─── node resolution ──────────────────────────────────────────────────────────

resolve_node() {
  local input="$1"
  local nodes_file="$2"

  # 1. Exact match on id (case-sensitive)
  local match
  match=$(jq -r --arg q "$input" '.nodes[] | select(.id == $q) | .id' "$nodes_file")
  if [[ -n "$match" ]]; then
    echo "$match"
    return 0
  fi

  # 2. Case-insensitive exact match on id
  local lower_input
  lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')
  match=$(jq -r --arg q "$lower_input" '.nodes[] | select((.id | ascii_downcase) == $q) | .id' "$nodes_file" | head -1)
  if [[ -n "$match" ]]; then
    echo "$match"
    return 0
  fi

  # 3. Substring match (case-insensitive) on id
  local matches
  matches=$(jq -r --arg q "$lower_input" '.nodes[] | select((.id | ascii_downcase) | contains($q)) | .id' "$nodes_file")
  local count
  count=$(echo "$matches" | grep -c . 2>/dev/null || echo 0)
  if [[ "$count" -eq 1 ]]; then
    echo "$matches"
    return 0
  elif [[ "$count" -gt 1 ]]; then
    err "Multiple matches for \"$input\":"
    local i=1
    while IFS= read -r m; do
      echo "  $i. $m" >&2
      ((i++)) || true
    done <<< "$matches"
    echo "Specify a full node name or use df-explain --node <exact-name>." >&2
    return 1
  fi

  # 4. File path match on file field
  match=$(jq -r --arg q "$input" '.nodes[] | select(.file == $q) | .id' "$nodes_file" | head -1)
  if [[ -n "$match" ]]; then
    echo "$match"
    return 0
  fi

  # 5. No match
  err "No memory found for \"$input\". It may need a df-sync or a classifier entry."
  return 1
}

# ─── BFS traversal ────────────────────────────────────────────────────────────

# Print a single node line: "  → NodeName [type] — intent [STALE marker]"
# direction: "out" (→) or "in" (←)
format_neighbour_line() {
  local node_json="$1" direction="$2"
  local id type intent stale arrow
  id=$(echo "$node_json" | jq -r '.id')
  type=$(echo "$node_json" | jq -r '.type')
  intent=$(echo "$node_json" | jq -r '.intent // "(no intent recorded)"')
  stale=$(echo "$node_json" | jq -r '.stale // false')
  arrow="→"
  [[ "$direction" == "in" ]] && arrow="←"

  local stale_marker=""
  if [[ "$stale" == "deleted" ]]; then
    stale_marker=" [STALE: deleted]"
  elif [[ "$stale" == "aged" ]]; then
    stale_marker=" [STALE: aged]"
  fi

  # Extract short name from id (last component after last dot or colon)
  local short_name
  short_name=$(echo "$id" | sed 's/.*[.:]//')

  printf '  %s %s [%s] — %s%s\n' "$arrow" "$short_name" "$type" "$intent" "$stale_marker"
}

# BFS: collect all node IDs reachable from start_id up to max_depth
# Populates global arrays: outbound_nodes, inbound_nodes (at depth 1)
# For depth > 1 we collect all reachable neighbours recursively
bfs_neighbours() {
  local start_id="$1" depth="$2" nodes_file="$3" edges_file="$4"

  # Collect direct outbound (from == start_id)
  local out_ids
  out_ids=$(jq -r --arg id "$start_id" '[.edges[] | select(.from == $id) | .to] | unique[]' "$edges_file" 2>/dev/null || echo "")

  # Collect direct inbound (to == start_id)
  local in_ids
  in_ids=$(jq -r --arg id "$start_id" '[.edges[] | select(.to == $id) | .from] | unique[]' "$edges_file" 2>/dev/null || echo "")

  echo "OUT:$out_ids"
  echo "IN:$in_ids"

  if [[ "$depth" -le 1 ]]; then
    return 0
  fi

  # Recurse for depth > 1 (collect extended neighbours)
  local next_depth=$(( depth - 1 ))
  while IFS= read -r nid; do
    [[ -z "$nid" ]] && continue
    bfs_neighbours "$nid" "$next_depth" "$nodes_file" "$edges_file"
  done <<< "$out_ids"
  while IFS= read -r nid; do
    [[ -z "$nid" ]] && continue
    bfs_neighbours "$nid" "$next_depth" "$nodes_file" "$edges_file"
  done <<< "$in_ids"
}

# ─── report output ────────────────────────────────────────────────────────────

print_node_report() {
  local node_id="$1" depth="$2" nodes_file="$3" edges_file="$4"

  # Get the node JSON
  local node_json
  node_json=$(jq -r --arg id "$node_id" '.nodes[] | select(.id == $id)' "$nodes_file")
  if [[ -z "$node_json" ]]; then
    err "Node \"$node_id\" not found in nodes.json."
    return 1
  fi

  local ntype nfile nintent nconfidence nstale
  ntype=$(echo "$node_json" | jq -r '.type')
  nfile=$(echo "$node_json" | jq -r '.file // "(unknown file)"')
  nintent=$(echo "$node_json" | jq -r '.intent // "(no intent recorded)"')
  nconfidence=$(echo "$node_json" | jq -r '.confidence')
  nstale=$(echo "$node_json" | jq -r '.stale // false')

  local short_name
  short_name=$(echo "$node_id" | sed 's/.*[.:]//')

  local stale_header=""
  if [[ "$nstale" == "deleted" ]]; then
    stale_header=" [STALE: deleted]"
  elif [[ "$nstale" == "aged" ]]; then
    stale_header=" [STALE: aged]"
  fi

  # Node card
  printf '[%s] %s — %s%s\n' "$short_name" "$ntype" "$nintent" "$stale_header"
  printf 'file: %s\n' "$nfile"
  printf 'confidence: %s\n' "$nconfidence"

  if [[ "$depth" -eq 0 ]]; then
    return 0
  fi

  # Collect direct outbound neighbours
  local out_ids
  mapfile -t out_ids < <(jq -r --arg id "$node_id" '.edges[] | select(.from == $id) | .to' "$edges_file" 2>/dev/null | sort -u || true)

  # Collect direct inbound neighbours
  local in_ids
  mapfile -t in_ids < <(jq -r --arg id "$node_id" '.edges[] | select(.to == $id) | .from' "$edges_file" 2>/dev/null | sort -u || true)

  # DEPENDS ON section
  if [[ "${#out_ids[@]}" -gt 0 ]]; then
    printf '\nDEPENDS ON (%d)\n' "${#out_ids[@]}"
    for nid in "${out_ids[@]}"; do
      local neighbour_json
      neighbour_json=$(jq -r --arg id "$nid" '.nodes[] | select(.id == $id)' "$nodes_file")
      if [[ -n "$neighbour_json" ]]; then
        format_neighbour_line "$neighbour_json" "out"
      fi
    done
  fi

  # DEPENDED ON BY section
  if [[ "${#in_ids[@]}" -gt 0 ]]; then
    printf '\nDEPENDED ON BY (%d) — changing %s affects these:\n' "${#in_ids[@]}" "$short_name"
    for nid in "${in_ids[@]}"; do
      local neighbour_json
      neighbour_json=$(jq -r --arg id "$nid" '.nodes[] | select(.id == $id)' "$nodes_file")
      if [[ -n "$neighbour_json" ]]; then
        format_neighbour_line "$neighbour_json" "in"
      fi
    done

    # Summary line
    local names=()
    for nid in "${in_ids[@]}"; do
      local sname
      sname=$(echo "$nid" | sed 's/.*[.:]//')
      names+=("$sname")
    done
    local joined
    joined=$(IFS=', '; echo "${names[*]}")
    printf '\n[DevFlow] %d node(s) depend on %s.\n' "${#in_ids[@]}" "$short_name"
    printf 'Changing its shape will affect %s.\n' "$joined"
  fi
}

# ─── commands ─────────────────────────────────────────────────────────────────

cmd_version() {
  echo "DevFlow $DEVFLOW_VERSION"
  exit 0
}

cmd_explain() {
  local input="$1" depth="$2" exact_node="$3"

  check_prereqs

  # Clamp depth
  if [[ "$depth" -gt "$MAX_DEPTH" ]]; then depth=$MAX_DEPTH; fi

  # CI mode: no .devflow/ → exit 0 silently
  local devflow_dir
  devflow_dir="$(git rev-parse --show-toplevel)/.devflow"
  if [[ ! -d "$devflow_dir" ]]; then
    exit 0
  fi

  local nodes_file="${devflow_dir}/active/nodes.json"
  local edges_file="${devflow_dir}/active/edges.json"

  if [[ ! -f "$nodes_file" ]] || [[ ! -f "$edges_file" ]]; then
    err "Memory not initialised. Run df-init first."
    exit 1
  fi

  local node_id
  if [[ -n "$exact_node" ]]; then
    # --node flag: exact lookup
    node_id=$(jq -r --arg id "$exact_node" '.nodes[] | select(.id == $id) | .id' "$nodes_file")
    if [[ -z "$node_id" ]]; then
      err "Node \"$exact_node\" not found in nodes.json."
      exit 1
    fi
  else
    node_id=$(resolve_node "$input" "$nodes_file") || exit 1
  fi

  print_node_report "$node_id" "$depth" "$nodes_file" "$edges_file"
}

# ─── dispatch ─────────────────────────────────────────────────────────────────

INPUT=""
DEPTH=1
EXACT_NODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) cmd_version ;;
    --depth)
      shift
      DEPTH="${1:-1}"
      shift
      ;;
    --node)
      shift
      EXACT_NODE="${1:-}"
      shift
      ;;
    -*)
      err "Unknown flag: $1"
      exit 1
      ;;
    *)
      INPUT="$1"
      shift
      ;;
  esac
done

if [[ -z "$INPUT" && -z "$EXACT_NODE" ]]; then
  err "Usage: df-explain <name-or-path> [--depth N] [--node <exact-id>]"
  exit 1
fi

cmd_explain "$INPUT" "$DEPTH" "$EXACT_NODE"
```

Make it executable:
```bash
chmod +x bin/df-explain
```

- [ ] **Step 2: Run df-explain tests**

```bash
bats tests/df-explain.bats
```

Expected: most tests pass. Fix any failures before proceeding — do NOT commit with failing tests.

- [ ] **Step 3: Run shellcheck**

```bash
shellcheck bin/df-explain
```

Expected: exit 0, no warnings.

- [ ] **Step 4: Commit**

```bash
git add bin/df-explain
git commit -m "feat: implement df-explain (node lookup, BFS traversal, structured output)"
```

---

## Task 4: Implement `bin/df-test`

**Files:**
- Modify: `bin/df-test`

- [ ] **Step 1: Write the full implementation**

Replace `bin/df-test` with:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── constants ────────────────────────────────────────────────────────────────

DEVFLOW_VERSION="0.1.0"

# ─── helpers ──────────────────────────────────────────────────────────────────

err() { echo "[DevFlow] $*" >&2; }

check_prereqs() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not a git repo."
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    err "Missing prerequisite: jq"
    exit 1
  fi
}

atomic_write() {
  local file="$1" content="$2"
  local tmp="${file}.tmp"
  if [[ -e "$file" && ! -w "$file" ]]; then return 1; fi
  printf '%s' "$content" > "$tmp"
  sync 2>/dev/null || true
  mv "$tmp" "$file"
}

# ─── commands ─────────────────────────────────────────────────────────────────

cmd_version() {
  echo "DevFlow $DEVFLOW_VERSION"
  exit 0
}

cmd_list() {
  check_prereqs

  local devflow_dir
  devflow_dir="$(git rev-parse --show-toplevel)/.devflow"
  local slices_file="${devflow_dir}/active/slices.json"

  if [[ ! -f "$slices_file" ]]; then
    err "No slice plan found. Run the feature skill to create one."
    exit 1
  fi

  local feature approved_at
  feature=$(jq -r '.feature' "$slices_file")
  approved_at=$(jq -r '.approved_at' "$slices_file")

  echo "Slice plan: $feature (approved $approved_at)"

  while IFS= read -r slice; do
    local id name status
    id=$(echo "$slice" | jq -r '.id')
    name=$(echo "$slice" | jq -r '.name')
    status=$(echo "$slice" | jq -r '.status')
    printf '  [%-11s] %d  %s\n' "$status" "$id" "$name"
  done < <(jq -c '.slices[]' "$slices_file")
}

cmd_run() {
  local slice_id="$1"

  check_prereqs

  local devflow_dir
  devflow_dir="$(git rev-parse --show-toplevel)/.devflow"
  local slices_file="${devflow_dir}/active/slices.json"

  # Check for DEVFLOW_TEST_CMD override first — can run even without slices.json
  if [[ -n "${DEVFLOW_TEST_CMD:-}" ]]; then
    echo "[DevFlow] Running slice $slice_id (DEVFLOW_TEST_CMD override)"
    set +e
    eval "$DEVFLOW_TEST_CMD"
    local exit_code=$?
    set -e
    if [[ "$exit_code" -eq 0 ]]; then
      echo "[DevFlow] PASS"
    else
      echo "[DevFlow] FAIL (exit $exit_code)"
    fi
    # Update slices.json if it exists
    if [[ -f "$slices_file" ]]; then
      local new_status="failed"
      [[ "$exit_code" -eq 0 ]] && new_status="done"
      local updated
      updated=$(jq --argjson id "$slice_id" --arg s "$new_status" \
        '.slices = [.slices[] | if .id == $id then .status = $s else . end]' \
        "$slices_file")
      atomic_write "$slices_file" "$updated"
    fi
    exit "$exit_code"
  fi

  # No env override — require slices.json
  if [[ ! -f "$slices_file" ]]; then
    if [[ ! -d "$devflow_dir" ]]; then
      err "No test command found. Set DEVFLOW_TEST_CMD or run df-init."
    else
      err "No slice plan found. Run the feature skill to create one."
    fi
    exit 1
  fi

  # Find the slice
  local slice_json
  slice_json=$(jq -r --argjson id "$slice_id" '.slices[] | select(.id == $id)' "$slices_file")
  if [[ -z "$slice_json" ]]; then
    err "Slice $slice_id not found in slices.json."
    exit 1
  fi

  local slice_name test_cmd
  slice_name=$(echo "$slice_json" | jq -r '.name')
  test_cmd=$(echo "$slice_json" | jq -r '.test_cmd // empty')

  if [[ -z "$test_cmd" ]]; then
    err "Slice $slice_id has no test_cmd defined."
    exit 1
  fi

  echo "[DevFlow] Running slice $slice_id: $slice_name"

  set +e
  eval "$test_cmd"
  local exit_code=$?
  set -e

  local new_status="failed"
  if [[ "$exit_code" -eq 0 ]]; then
    echo "[DevFlow] PASS"
    new_status="done"
  else
    echo "[DevFlow] FAIL (exit $exit_code)"
  fi

  # Write status back atomically
  local updated
  updated=$(jq --argjson id "$slice_id" --arg s "$new_status" \
    '.slices = [.slices[] | if .id == $id then .status = $s else . end]' \
    "$slices_file")
  atomic_write "$slices_file" "$updated"

  exit "$exit_code"
}

# ─── dispatch ─────────────────────────────────────────────────────────────────

case "${1:-}" in
  --version) cmd_version ;;
  --list)    cmd_list ;;
  ''|-*)
    err "Usage: df-test <slice-id> | --list | --version"
    exit 1
    ;;
  *)
    SLICE_ID="$1"
    # Validate it's a number
    if ! [[ "$SLICE_ID" =~ ^[0-9]+$ ]]; then
      err "Slice ID must be a positive integer. Got: $SLICE_ID"
      exit 1
    fi
    cmd_run "$SLICE_ID"
    ;;
esac
```

Make it executable:
```bash
chmod +x bin/df-test
```

- [ ] **Step 2: Run df-test tests**

```bash
bats tests/df-test.bats
```

Expected: all 11 tests pass. Fix any failures before proceeding.

- [ ] **Step 3: Run shellcheck**

```bash
shellcheck bin/df-test
```

Expected: exit 0, no warnings.

- [ ] **Step 4: Commit**

```bash
git add bin/df-test
git commit -m "feat: implement df-test (slice test runner with slices.json write-back)"
```

---

## Task 5: Run Full Test Suite + Fix Failures

**Files:**
- Modify: `bin/df-explain` (if shellcheck or test failures found)
- Modify: `bin/df-test` (if shellcheck or test failures found)
- Modify: `tests/df-explain.bats` (if test logic needs correction)
- Modify: `tests/df-test.bats` (if test logic needs correction)

- [ ] **Step 1: Run all bats suites**

```bash
bats tests/df-explain.bats
bats tests/df-test.bats
bats tests/df-init.bats
bats tests/df-sync.bats
```

Expected:
- `tests/df-explain.bats`: all tests pass
- `tests/df-test.bats`: all tests pass
- `tests/df-init.bats`: 30/30 (no regression)
- `tests/df-sync.bats`: 20/20 (no regression)

- [ ] **Step 2: Run shellcheck on all scripts**

```bash
shellcheck bin/df-explain bin/df-test bin/df-init bin/df-sync
```

Expected: exit 0 for all, no warnings.

- [ ] **Step 3: Fix any failures**

Common known issues to watch for:

**In df-explain:**
- `local x; x=$(...)` pattern — never `local x=$(...)` (SC2155)
- `mapfile -t` for arrays from command output — never `arr=( $(cmd) )` (SC2207)
- `((i++)) || true` for arithmetic that might return 0
- `jq -r` returns empty string (not null) when field missing — guard with `// empty` or `// "(fallback)"`
- The `count` variable from `grep -c`: when input is empty string, `grep -c .` returns 0 and exits 1 — guard with `|| echo 0`

**In df-test:**
- `eval "$test_cmd"` is intentional (allows compound commands) — add `# shellcheck disable=SC2294` if needed
- `set +e / set -e` around test execution to capture exit code without aborting script

- [ ] **Step 4: Commit if any fixes were made**

```bash
git add bin/df-explain bin/df-test tests/df-explain.bats tests/df-test.bats
git commit -m "fix: df-explain and df-test test suite and shellcheck fixes"
```

If nothing changed, skip this step.

---

## Task 6: Write `skills/fix/SKILL.md`

**Files:**
- Create: `skills/fix/SKILL.md`
- Remove: `skills/fix/.gitkeep` (replace with SKILL.md)

- [ ] **Step 1: Write SKILL.md**

Create `skills/fix/SKILL.md`:

````markdown
# Fix Skill

Trigger: `/fix "<description of what's broken>"`

Examples:
- `/fix "comments endpoint returns 500 on empty body"`
- `/fix "UserService throws NullReferenceException on login"`

---

## Pre-flight Checks

Run BEFORE any reasoning or file reading:

### 1. Memory staleness

Read `.devflow/config.json`. Check two conditions:

```bash
git rev-parse HEAD   # get current HEAD SHA
```

- If `dirty` field is `true`, OR
- If `last_synced` value ≠ current HEAD SHA

Then run:

```bash
df-sync
```

Print: `[DevFlow] Memory was stale — synced to <sha> before proceeding.`

### 2. Conflict check

Check if `.devflow/active/graph_conflicts.json` exists:

```bash
ls .devflow/active/graph_conflicts.json 2>/dev/null
```

If it exists: print all conflicted node IDs from the file, then print:

```
[DevFlow] Unresolved graph conflicts detected. Run df-resolve before proceeding.
Affected nodes: <list node ids>
```

**HALT — do not proceed until developer runs df-resolve.**

---

## Step 1 — Node Inference + Confirmation

Parse the developer's description and identify the most likely node (entity, route, or service).

Show the inferred node:

```
I think this is about [CommentController] (route) — src/routes/CommentController.svelte.
Is that right? (Y / different node)
```

- If developer confirms (Y or equivalent) → proceed
- If developer specifies a different node → use that node name instead

Then run:

```bash
df-explain <node-name>
```

Read and internalize the full output — especially the DEPENDS ON and DEPENDED ON BY sections.

---

## Step 2 — Context Loading

Read in this exact order, **before opening any source files**:

1. The `df-explain` output from Step 1 (already loaded)
2. `.devflow/active/memory.md` — specifically the architecture and conventions sections

Do NOT open any `.cs`, `.svelte`, `.ts`, or other source files yet.

---

## Step 3 — Hypothesis Formation

State a hypothesis explicitly before reading any code.

Format:

```
Hypothesis [cycle 1/3]: <one paragraph description of what you think is wrong and why>

Files to read (from df-explain output):
  - <file 1>  (<reason: inbound/outbound node, or architecture section>)
  - <file 2>  (<reason>)

Reading these files — does this look right? (Y / adjust list)
```

Wait for developer confirmation (or immediate proceed if no objection). Then read ONLY those files.

---

## Cycle Loop (max 3 cycles)

Each cycle = one hypothesis + targeted file reads + one fix attempt + one test run.

### Apply the fix

Edit only the files identified in the current hypothesis. Do not touch files outside the hypothesis scope unless the fix mechanically requires it (e.g., updating an interface used by the changed file).

### Determine the test command

Check in this order:

1. Does `.devflow/active/slices.json` exist?
2. Does its `feature` field match the current git branch name (`git rev-parse --abbrev-ref HEAD`)?
3. Does at least one slice have `status` ≠ `"done"`?

If all three are true:
- Identify the most relevant slice (the one whose `layers` or `result` description best matches the broken thing)
- Run: `df-test <slice-id>`

Otherwise:
- Read `test_cmd` from `.devflow/config.json`
- Run that command

If no test command is available from either source: tell the developer:
```
[DevFlow] No test command found. Please provide a test command to run.
```
Wait for the developer to provide one before continuing.

### On PASS

Break out of cycle loop. Go to **Success output**.

### On FAIL

1. State what the failure reveals: `"The test failed with <error>. This suggests <revised hypothesis>."`
2. Identify any new files to read if needed
3. Increment cycle counter
4. Start next cycle

### After 3 failed cycles

Do NOT attempt a 4th cycle. Print:

```
[DevFlow] Could not fix after 3 cycles. Here's what I found:

Cycle 1: <hypothesis + what happened>
Cycle 2: <hypothesis + what happened>
Cycle 3: <hypothesis + what happened>

Current state: <describe what was changed, whether changes were reverted>
Suggested next steps: <specific diagnostic hints for the developer>
```

---

## Success Output

```
[DevFlow] Fixed in <N> cycle(s).
Hypothesis: <winning hypothesis in one sentence>
Files changed: <list>
Suggested commit: fix: <short description>
```

---

## Error Reference

| Condition | Behaviour |
|---|---|
| Memory stale (dirty or SHA mismatch) | Auto-run df-sync, print message, continue |
| `graph_conflicts.json` exists | Print conflicted nodes, halt until df-resolve is run |
| `df-explain` returns multiple matches | Ask developer to be more specific before continuing |
| `df-explain` returns no match | Ask developer to specify a different starting node |
| No test command available | Ask developer to provide test command |
| `df-test` not on PATH | Fall back to `test_cmd` from `config.json` with warning: `[DevFlow] df-test not found — using config test_cmd` |
| 3 cycles exhausted | Surface findings and diagnosis, do not attempt 4th cycle |

---

## Notes

- Never read more files than the hypothesis requires
- Never modify files outside the hypothesis scope without stating why
- Hypothesis must be stated before reading any source file — this is a discipline, not a suggestion
- The fix is not done until the test passes — a hypothesis without a passing test is not a fix
````

- [ ] **Step 2: Remove .gitkeep placeholder**

```bash
rm skills/fix/.gitkeep
```

- [ ] **Step 3: Verify SKILL.md looks correct**

```bash
wc -l skills/fix/SKILL.md
cat skills/fix/SKILL.md | head -20
```

Expected: file exists, starts with `# Fix Skill`.

- [ ] **Step 4: Commit**

```bash
git add skills/fix/SKILL.md skills/fix/.gitkeep
git commit -m "feat: add fix skill (memory-aware bug fix with df-explain + df-test)"
```

---

## Task 7: End-to-End Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full bats suite**

```bash
bats tests/df-explain.bats
bats tests/df-test.bats
bats tests/df-init.bats
bats tests/df-sync.bats
```

Expected: all tests pass across all four suites.

- [ ] **Step 2: Run shellcheck on all scripts**

```bash
shellcheck bin/df-explain bin/df-test bin/df-init bin/df-sync
```

Expected: exit 0 for all, no warnings.

- [ ] **Step 3: End-to-end df-explain on the DevFlow repo**

```bash
export PATH="/Volumes/ReydoSSD/SourceCode/Development-Flow/bin:$PATH"
cd /Volumes/ReydoSSD/SourceCode/Development-Flow

# If .devflow/ exists and has nodes.json:
df-explain --version
# If nodes.json has any nodes, try resolving one:
# df-explain <first-node-id>
# Otherwise confirm CI mode exit 0:
echo "Exit: $?"
```

- [ ] **Step 4: End-to-end df-test on a temp repo**

```bash
tmpdir=$(mktemp -d)
cd "$tmpdir"
git init -b main
git config user.email "t@t.com" && git config user.name "T"
git commit --allow-empty -m "initial"

mkdir -p .devflow/branches/main
cat > .devflow/branches/main/slices.json << 'EOF'
{
  "feature": "e2e-test",
  "approved_at": "2026-04-30T00:00:00Z",
  "slices": [
    {"id": 1, "name": "smoke test", "layers": ["api"], "result": "passes", "test_cmd": "echo SMOKE_PASS", "depends_on": [], "status": "pending"}
  ]
}
EOF
ln -sfn "branches/main" .devflow/active

PATH="/Volumes/ReydoSSD/SourceCode/Development-Flow/bin:$PATH" df-test 1
echo "Exit: $?"
jq '.slices[0].status' .devflow/branches/main/slices.json  # should be "done"
PATH="/Volumes/ReydoSSD/SourceCode/Development-Flow/bin:$PATH" df-test --list

cd /Volumes/ReydoSSD/SourceCode/Development-Flow
rm -rf "$tmpdir"
```

Expected: `df-test 1` prints `[DevFlow] Running slice 1: smoke test`, `SMOKE_PASS`, `[DevFlow] PASS`. Status is `"done"`. `--list` shows `[done]` for slice 1.

- [ ] **Step 5: Commit if any files changed**

```bash
git status
# Only commit if there are actual changes
```

---

## Definition of Done

- [ ] `bin/df-explain` passes `shellcheck` with zero warnings
- [ ] All `tests/df-explain.bats` tests pass
- [ ] `bin/df-test` passes `shellcheck` with zero warnings
- [ ] All `tests/df-test.bats` tests pass
- [ ] `skills/fix/SKILL.md` written and complete
- [ ] No regressions in `tests/df-init.bats` or `tests/df-sync.bats`
- [ ] Both scripts work end-to-end

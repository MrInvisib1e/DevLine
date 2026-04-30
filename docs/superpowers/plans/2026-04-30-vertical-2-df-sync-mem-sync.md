# df-sync + mem-sync Skill — Vertical 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `bin/df-sync` (post-commit and branch-switch graph memory sync) and `skills/mem-sync/SKILL.md` (AI skill wrapper), passing all bats tests with DEVFLOW_AI_MOCK=1.

**Architecture:** Single bash script `bin/df-sync` with no shared libraries. All modes (`--sync`, `--branch-switch`, `--force`, `--force --all`) in one file, following exact patterns from `bin/df-init` (atomic writes, flock/PID lock, dirty flag, `err()` helper). AI calls are mocked via `DEVFLOW_AI_MOCK=1` using a fixture file.

**Tech Stack:** bash 5+, bats 1.13, jq 1.6+, git. No external dependencies beyond what df-init already uses.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `bin/df-sync` | Create | Main script — `--version`, `--scan` (reserved), `--force`, `--force --all`, `--branch-switch` |
| `skills/mem-sync/SKILL.md` | Create | 4-step AI skill: check staleness → run df-sync → verify → retry |
| `tests/df-sync.bats` | Create | Full bats test suite (22 test cases) |
| `tests/fixtures/ai-responses/df-sync-response.json` | Create | Mock AI batch response fixture |

---

## Shared Context (read before every task)

**Repo:** `/Volumes/ReydoSSD/SourceCode/Development-Flow`

**Key patterns from df-init to reuse:**
- `err()`: `echo "[DevFlow] $*" >&2`
- `atomic_write <file> <content>`: write to `.tmp`, `sync`, `mv`
- `canonicalize_branch`: `echo "${1//\//__}"`
- `check_prereqs`: verify git repo + jq installed
- Lock: `flock -n "$lock_fd" 2>/dev/null` with PID-file fallback
- `install_hook`: idempotent hook install with `# DevFlow managed` header
- `classify_file`: bash `case` with `*` glob matching `/`

**Node ID formula:** `<type>:<path-with-dots-no-last-extension>`
- `Entities/Comment.cs` → `entity:Entities.Comment`
- `Services/CommentService.cs` → `service:Services.CommentService`
- `src/routes/+page.svelte` → `route:src.routes.+page`
- Strip only the LAST extension: `slug.test.ts` → `service:slug.test`

**Typed stale values:** `"deleted"` (file gone from HEAD) | `"aged"` (not in diff for N commits) | omitted when false

**confidence values:** `"manual"` | `"high"` | `"inferred"` | `"ai"`

**Spec files:**
- `docs/superpowers/specs/2026-04-30-vertical-2-df-sync-skill.md`
- `docs/superpowers/specs/2026-04-29-graph-memory-design.md`

**Test fixture:** `tests/fixtures/sample-repo/` — same as Vertical 1 (Program.cs, vite.config.ts, package.json, Entities/Comment.cs, Services/CommentService.cs, Contracts/CommentCreatedEvent.cs, src/routes/+page.svelte, src/lib/utils/slug.ts)

---

## Task 1: Scaffolding + Fixture Files

**Files:**
- Create: `tests/fixtures/ai-responses/df-sync-response.json`
- Create: `bin/df-sync` (executable stub)
- Create: `tests/df-sync.bats` (empty setup/teardown only)
- Create: `skills/mem-sync/` (directory)

- [ ] **Step 1: Create the AI mock fixture**

```bash
cat > tests/fixtures/ai-responses/df-sync-response.json << 'EOF'
{
  "batch": [
    {
      "path": "Entities/Comment.cs",
      "intent": "Soft-deletable content unit attached to a story",
      "confidence": "ai",
      "edges": [
        { "to_file": "Services/CommentService.cs", "rel": "uses" }
      ]
    },
    {
      "path": "Services/CommentService.cs",
      "intent": "Owns all comment mutations",
      "confidence": "ai",
      "edges": []
    },
    {
      "path": "Contracts/CommentCreatedEvent.cs",
      "intent": "Event emitted when a new comment is created",
      "confidence": "ai",
      "edges": []
    },
    {
      "path": "src/routes/+page.svelte",
      "intent": "Home page route",
      "confidence": "ai",
      "edges": []
    },
    {
      "path": "src/lib/utils/slug.ts",
      "intent": "URL slug utility",
      "confidence": "ai",
      "edges": []
    }
  ]
}
EOF
```

- [ ] **Step 2: Create the df-sync stub**

```bash
cat > bin/df-sync << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

DEVFLOW_VERSION="0.1.0"

err() { echo "[DevFlow] $*" >&2; }

echo "[DevFlow] df-sync stub — not yet implemented" >&2
exit 1
EOF
chmod +x bin/df-sync
```

- [ ] **Step 3: Create the bats test file with setup/teardown only**

```bash
cat > tests/df-sync.bats << 'EOF'
#!/usr/bin/env bats

setup() {
  export REPO
  REPO="$(mktemp -d)"
  cp -r "$BATS_TEST_DIRNAME/fixtures/sample-repo/." "$REPO/"
  (cd "$REPO" && git init -b main && git add . && git commit -m "initial" --quiet)
  export FIXTURE_AI="$BATS_TEST_DIRNAME/fixtures/ai-responses/df-sync-response.json"
  export DF_SYNC="$BATS_TEST_DIRNAME/../bin/df-sync"
  export DF_INIT="$BATS_TEST_DIRNAME/../bin/df-init"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  export DEVFLOW_AI_MOCK=1
  export DEVFLOW_AI_MOCK_FILE="$FIXTURE_AI"
}

teardown() {
  rm -rf "$REPO"
}

# placeholder — tests added in Task 2
@test "placeholder passes" {
  true
}
EOF
```

- [ ] **Step 4: Create the mem-sync skill directory**

```bash
mkdir -p skills/mem-sync
```

- [ ] **Step 5: Verify fixture is valid JSON**

```bash
jq . tests/fixtures/ai-responses/df-sync-response.json
```

Expected: JSON printed without errors. `batch` array with 5 entries.

- [ ] **Step 6: Run placeholder test**

```bash
bats tests/df-sync.bats
```

Expected: `1 test, 0 failures`

- [ ] **Step 7: Commit**

```bash
git add bin/df-sync tests/df-sync.bats tests/fixtures/ai-responses/df-sync-response.json skills/mem-sync/
git commit -m "chore: scaffold df-sync vertical-2 files"
```

---

## Task 2: Write Failing Tests (TDD Baseline)

**Files:**
- Modify: `tests/df-sync.bats`

Write all 22 tests. All should fail with exit 1 "stub — not yet implemented".

- [ ] **Step 1: Replace placeholder with full test suite**

Write `tests/df-sync.bats`:

```bash
#!/usr/bin/env bats

# ─── helpers ──────────────────────────────────────────────────────────────────

setup() {
  export REPO
  REPO="$(mktemp -d)"
  cp -r "$BATS_TEST_DIRNAME/fixtures/sample-repo/." "$REPO/"
  (cd "$REPO" && git init -b main && git add . && git commit -m "initial" --quiet)
  export FIXTURE_AI="$BATS_TEST_DIRNAME/fixtures/ai-responses/df-sync-response.json"
  export DF_SYNC="$BATS_TEST_DIRNAME/../bin/df-sync"
  export DF_INIT="$BATS_TEST_DIRNAME/../bin/df-init"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  export DEVFLOW_AI_MOCK=1
  export DEVFLOW_AI_MOCK_FILE="$FIXTURE_AI"
}

teardown() {
  rm -rf "$REPO"
}

# Helper: run df-init --write-memory with a minimal patch for main branch
_init_repo() {
  local repo="$1"
  local patch
  patch=$(jq -n \
    --arg sha "$(cd "$repo" && git rev-parse HEAD)" \
    '{
      config: {
        service: "test-repo",
        workspace: null,
        stack: {runtime: "dotnet-9", frontend: "sveltekit", test_cmd: "dotnet test"},
        last_synced: $sha,
        schema_version: 1,
        node_types: {custom: []},
        edge_staleness_threshold: 30,
        no_intent_recheck: [],
        edge_rel_types: {builtin: ["depends_on","uses","persisted_in","implements","emits","handles"], custom: []},
        graph_limits: {max_nodes: 2000, max_edges: 10000, prune_min_age_commits: 90, max_files_per_sync: 200},
        classifiers: []
      },
      memory: {
        stack: {runtime: "dotnet-9", frontend: "sveltekit", test_cmd: "dotnet test", key_dependencies: []},
        architecture: {},
        conventions: {},
        architecture_last_synced: $sha
      },
      nodes: {
        schema_version: 1,
        nodes: [
          {id: "entity:Entities.Comment", name: "Comment", type: "entity", file: "Entities/Comment.cs",
           intent: "Soft-deletable content unit", confidence: "high", last_seen: $sha}
        ]
      },
      edges: {schema_version: 1, edges: []}
    }')
  printf '%s' "$patch" | bash -c "cd '$repo' && '$DF_INIT' --write-memory"
}

# ─── --version ────────────────────────────────────────────────────────────────

@test "df-sync --version prints DevFlow version and exits 0" {
  run "$DF_SYNC" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── post-commit: basic sync ──────────────────────────────────────────────────

@test "post-commit: new file gets node in nodes.json with intent" {
  _init_repo "$REPO"
  # Make a new commit touching a new entity file
  echo "// new entity" > "$REPO/Entities/Story.cs"
  (cd "$REPO" && git add . && git commit -m "add story entity" --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC'"
  [ "$status" -eq 0 ]
  node_count=$(jq '.nodes | length' "$REPO/.devflow/active/nodes.json")
  [ "$node_count" -gt 1 ]
}

@test "post-commit: static edges parsed from TS import" {
  _init_repo "$REPO"
  # Add a TS file that imports slug
  cat > "$REPO/src/routes/story.ts" << 'TSEOF'
import { slugify } from '../lib/utils/slug';
export function getStorySlug(title: string) { return slugify(title); }
TSEOF
  (cd "$REPO" && git add . && git commit -m "add story route" --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC'"
  [ "$status" -eq 0 ]
  edge_count=$(jq '.edges | length' "$REPO/.devflow/active/edges.json")
  [ "$edge_count" -gt 0 ]
}

@test "post-commit: deleted file node marked stale:deleted" {
  _init_repo "$REPO"
  (cd "$REPO" && git rm Entities/Comment.cs --quiet && git commit -m "delete Comment" --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC'"
  [ "$status" -eq 0 ]
  stale=$(jq -r '.nodes[] | select(.id == "entity:Entities.Comment") | .stale' "$REPO/.devflow/active/nodes.json")
  [ "$stale" = "deleted" ]
}

@test "post-commit: last_synced updated to HEAD SHA after sync" {
  _init_repo "$REPO"
  echo "// change" >> "$REPO/Entities/Comment.cs"
  (cd "$REPO" && git add . && git commit -m "modify Comment" --quiet)
  local head_sha
  head_sha=$(cd "$REPO" && git rev-parse HEAD)
  run bash -c "cd '$REPO' && '$DF_SYNC'"
  [ "$status" -eq 0 ]
  synced=$(jq -r '.last_synced' "$REPO/.devflow/config.json")
  [ "$synced" = "$head_sha" ]
}

@test "post-commit: memory.md regenerated after sync" {
  _init_repo "$REPO"
  echo "// change" >> "$REPO/Entities/Comment.cs"
  (cd "$REPO" && git add . && git commit -m "modify Comment" --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC'"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.devflow/active/memory.md" ]
  grep -q "entity" "$REPO/.devflow/active/memory.md"
}

@test "post-commit: dirty protocol — dirty:true before writes, dirty:false after success" {
  _init_repo "$REPO"
  echo "// change" >> "$REPO/Entities/Comment.cs"
  (cd "$REPO" && git add . && git commit -m "modify Comment" --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC'"
  [ "$status" -eq 0 ]
  dirty=$(jq -r '.dirty' "$REPO/.devflow/config.json")
  [ "$dirty" = "false" ]
}

# ─── --force ──────────────────────────────────────────────────────────────────

@test "--force syncs all files regardless of last_synced" {
  _init_repo "$REPO"
  run bash -c "cd '$REPO' && '$DF_SYNC' --force"
  [ "$status" -eq 0 ]
  node_count=$(jq '.nodes | length' "$REPO/.devflow/active/nodes.json")
  [ "$node_count" -ge 4 ]
}

@test "--force --all bypasses max_files_per_sync cap" {
  _init_repo "$REPO"
  # Set cap to 1 via a patched config
  local cfg_file="$REPO/.devflow/config.json"
  local updated
  updated=$(jq '.graph_limits.max_files_per_sync = 1' "$cfg_file")
  printf '%s' "$updated" > "$cfg_file"
  run bash -c "cd '$REPO' && '$DF_SYNC' --force --all"
  [ "$status" -eq 0 ]
  # All files processed: no warning about cap
  [[ ! "$output" =~ "capped at" ]]
}

@test "large repo cap: warns and caps when changed files exceed max_files_per_sync" {
  _init_repo "$REPO"
  # Set cap to 2
  local cfg_file="$REPO/.devflow/config.json"
  local updated
  updated=$(jq '.graph_limits.max_files_per_sync = 2' "$cfg_file")
  printf '%s' "$updated" > "$cfg_file"
  run bash -c "cd '$REPO' && '$DF_SYNC' --force"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "capped at" ]] || [[ "$stderr" =~ "capped at" ]]
}

# ─── concurrent lock ──────────────────────────────────────────────────────────

@test "concurrent lock: second df-sync exits 0 with skip message" {
  _init_repo "$REPO"
  # Create a lock file manually
  mkdir -p "$REPO/.devflow"
  echo "99999" > "$REPO/.devflow/sync.lock"
  # Run df-sync; it should detect lock and exit 0
  run bash -c "cd '$REPO' && '$DF_SYNC'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "sync already running" ]] || [[ "$output" =~ "skipping" ]]
}

# ─── AI mock mode ─────────────────────────────────────────────────────────────

@test "AI mock mode: DEVFLOW_AI_MOCK=1 uses fixture, exit 0" {
  _init_repo "$REPO"
  echo "// change" >> "$REPO/Entities/Comment.cs"
  (cd "$REPO" && git add . && git commit -m "modify Comment" --quiet)
  run bash -c "cd '$REPO' && DEVFLOW_AI_MOCK=1 DEVFLOW_AI_MOCK_FILE='$FIXTURE_AI' '$DF_SYNC'"
  [ "$status" -eq 0 ]
}

@test "manual node preserved: confidence:manual node not overwritten by sync" {
  _init_repo "$REPO"
  # Manually set a node to confidence:manual
  local nodes_file="$REPO/.devflow/active/nodes.json"
  local updated
  updated=$(jq '(.nodes[] | select(.id == "entity:Entities.Comment")).confidence = "manual"' "$nodes_file")
  printf '%s' "$updated" > "$nodes_file"
  echo "// change" >> "$REPO/Entities/Comment.cs"
  (cd "$REPO" && git add . && git commit -m "modify Comment" --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC'"
  [ "$status" -eq 0 ]
  confidence=$(jq -r '.nodes[] | select(.id == "entity:Entities.Comment") | .confidence' "$REPO/.devflow/active/nodes.json")
  [ "$confidence" = "manual" ]
}

# ─── branch-switch ────────────────────────────────────────────────────────────

@test "branch-switch: active symlink points to new branch" {
  _init_repo "$REPO"
  (cd "$REPO" && git checkout -b feature-x --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC' --branch-switch"
  [ "$status" -eq 0 ]
  link_target=$(readlink "$REPO/.devflow/active")
  [[ "$link_target" =~ "feature-x" ]] || [[ "$link_target" =~ "feature__x" ]]
}

@test "branch-switch: new branch bootstrapped from nearest existing branch" {
  _init_repo "$REPO"
  (cd "$REPO" && git checkout -b feature-y --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC' --branch-switch"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.devflow/active/nodes.json" ]
}

@test "branch-switch: conflict detection writes graph_conflicts.json when intents differ" {
  _init_repo "$REPO"
  # Simulate two branches with different intent for same node
  local nodes_file="$REPO/.devflow/active/nodes.json"
  local updated
  updated=$(jq '(.nodes[] | select(.id == "entity:Entities.Comment")).intent = "branch A intent"' "$nodes_file")
  printf '%s' "$updated" > "$nodes_file"
  (cd "$REPO" && git checkout -b conflict-branch --quiet)
  # Simulate the active branch having different intent
  local nodes_file2="$REPO/.devflow/branches/main/nodes.json"
  updated=$(jq '(.nodes[] | select(.id == "entity:Entities.Comment")).intent = "branch B intent"' "$nodes_file2")
  printf '%s' "$updated" > "$nodes_file2"
  run bash -c "cd '$REPO' && '$DF_SYNC' --branch-switch"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.devflow/active/graph_conflicts.json" ]
}

@test "branch-switch: no conflicts — graph_conflicts.json absent" {
  _init_repo "$REPO"
  (cd "$REPO" && git checkout -b no-conflict-branch --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC' --branch-switch"
  [ "$status" -eq 0 ]
  [ ! -f "$REPO/.devflow/active/graph_conflicts.json" ]
}

@test "branch-switch: stale branch cleanup removes memory for deleted branches" {
  _init_repo "$REPO"
  # Create a ghost branch dir with no matching git branch
  mkdir -p "$REPO/.devflow/branches/ghost-branch"
  echo '{"schema_version":1,"nodes":[]}' > "$REPO/.devflow/branches/ghost-branch/nodes.json"
  (cd "$REPO" && git checkout -b cleanup-test --quiet)
  run bash -c "cd '$REPO' && '$DF_SYNC' --branch-switch"
  [ "$status" -eq 0 ]
  [ ! -d "$REPO/.devflow/branches/ghost-branch" ]
}

# ─── CI mode ──────────────────────────────────────────────────────────────────

@test "CI mode: no .devflow/ directory — exit 0 silently" {
  run bash -c "cd '$REPO' && '$DF_SYNC'"
  [ "$status" -eq 0 ]
}

# ─── error paths ──────────────────────────────────────────────────────────────

@test "not a git repo: exit 1 with correct message" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  run bash -c "cd '$tmpdir' && '$DF_SYNC'"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not a git repo" ]]
  rm -rf "$tmpdir"
}
```

- [ ] **Step 2: Run all tests to confirm they fail**

```bash
bats tests/df-sync.bats
```

Expected: All tests fail (exit 1 "stub — not yet implemented") except the CI mode test (no `.devflow/` present in `$REPO` before `_init_repo` is called) and possibly `--version`. That's fine — we want failures driven by missing implementation.

- [ ] **Step 3: Commit**

```bash
git add tests/df-sync.bats
git commit -m "test: add failing df-sync bats test suite (TDD baseline)"
```

---

## Task 3: Implement `--version`, prereqs, lock, CI mode, `--force` + `--force --all`

**Files:**
- Modify: `bin/df-sync`

- [ ] **Step 1: Write the full df-sync script (version + prereqs + lock + CI + force)**

Replace `bin/df-sync` entirely:

```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── constants ────────────────────────────────────────────────────────────────

DEVFLOW_VERSION="0.1.0"
DEVFLOW_DIR=".devflow"
LOCK_FILE="${DEVFLOW_DIR}/sync.lock"

# ─── helpers ──────────────────────────────────────────────────────────────────

err() { echo "[DevFlow] $*" >&2; }

check_prereqs() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not a git repo. Run df-sync inside a git repository."
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    err "Missing prerequisite: jq >= 1.6 is required. Install with: brew install jq"
    exit 1
  fi
}

canonicalize_branch() {
  echo "${1//\//__}"
}

# atomic_write <file> <content>
atomic_write() {
  local file="$1"
  local content="$2"
  local tmp="${file}.tmp"
  if [[ -e "$file" && ! -w "$file" ]]; then
    err "Cannot write to $file: permission denied"
    return 1
  fi
  printf '%s' "$content" > "$tmp"
  sync 2>/dev/null || true
  mv "$tmp" "$file"
}

# ─── lock ─────────────────────────────────────────────────────────────────────

acquire_lock() {
  mkdir -p "$DEVFLOW_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec {lock_fd}>"$LOCK_FILE"
    if ! flock -n "$lock_fd" 2>/dev/null; then
      echo "[DevFlow] sync already running — skipping"
      exit 0
    fi
    trap 'flock -u "$lock_fd" 2>/dev/null || true; rm -f "$LOCK_FILE"' EXIT
  else
    # PID-file fallback
    if [[ -f "$LOCK_FILE" ]]; then
      local old_pid
      old_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
      if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        echo "[DevFlow] sync already running — skipping"
        exit 0
      fi
    fi
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
  fi
}

# ─── classifier ───────────────────────────────────────────────────────────────

DEFAULT_CLASSIFIERS=(
  "entity:*Entities/*.cs:*Models/*.cs:*Domain/*.cs:*Domain/*/*.cs"
  "route:*Controller.cs:*Endpoint.cs:*pages/*.svelte:*pages/*/*.svelte:*routes/*.svelte:*routes/*/*.svelte:*routes/*.ts:*routes/*/*.ts"
  "contract:*Contracts/*:*Events/*:*Messages/*"
  "service:*Services/*.cs:*Handlers/*.cs"
  "conventions:.editorconfig:*.globalconfig:.eslintrc*:*.prettierrc*"
  "architecture:Program.cs:Startup.cs:appsettings*.json:vite.config.*"
)

classify_file() {
  local file="$1"
  local classifiers_json="${2:-}"
  local type=""

  # Try project classifiers from config.json first
  if [[ -n "$classifiers_json" ]] && [[ "$classifiers_json" != "[]" ]] && [[ "$classifiers_json" != "null" ]]; then
    local n
    n=$(echo "$classifiers_json" | jq 'length')
    for ((i=0; i<n; i++)); do
      local entry_type entry_pattern
      entry_type=$(echo "$classifiers_json" | jq -r ".[$i].type")
      entry_pattern=$(echo "$classifiers_json" | jq -r ".[$i].pattern")
      # shellcheck disable=SC2254
      case "$file" in
        $entry_pattern) type="$entry_type"; break ;;
      esac
    done
  fi

  # Fall back to DEFAULT_CLASSIFIERS
  if [[ -z "$type" ]]; then
    for entry in "${DEFAULT_CLASSIFIERS[@]}"; do
      local entry_type="${entry%%:*}"
      local patterns="${entry#*:}"
      IFS=':' read -ra pats <<< "$patterns"
      for pat in "${pats[@]}"; do
        # shellcheck disable=SC2254
        case "$file" in
          $pat) type="$entry_type"; break 2 ;;
        esac
      done
    done
  fi

  echo "$type"
}

# ─── node ID formula ──────────────────────────────────────────────────────────

file_to_node_id() {
  local file="$1"
  local type="$2"
  # Strip only the last extension, replace / with .
  local base="${file%.*}"
  local slug="${base//\//.}"
  echo "${type}:${slug}"
}

# ─── static edges ─────────────────────────────────────────────────────────────

static_edges() {
  local file="$1"
  local node_id="$2"
  local edges_json="[]"

  [[ -f "$file" ]] || { echo "[]"; return; }

  local ext="${file##*.}"
  case "$ext" in
    ts|svelte)
      # Match: import ... from './relative' or '../relative'
      while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*import.*from[[:space:]]+[\'\"](\./|\.\./) ]]; then
          local raw_path="${BASH_REMATCH[1]}"
          # Extract the quoted path
          local quoted
          quoted=$(echo "$line" | grep -oP "(?<=from ['\"])[^'\"]+(?=['\"])" || true)
          if [[ -n "$quoted" ]]; then
            edges_json=$(echo "$edges_json" | jq \
              --arg from "$node_id" \
              --arg to_path "$quoted" \
              --arg rel "uses" \
              '. + [{"from": $from, "to_path": $to_path, "rel": $rel, "source": "static"}]')
          fi
        fi
      done < "$file"
      ;;
    cs)
      # Match: using Namespace;
      while IFS= read -r line; do
        if [[ "$line" =~ ^using[[:space:]]+([A-Za-z][A-Za-z0-9._]*)\; ]]; then
          local ns="${BASH_REMATCH[1]}"
          edges_json=$(echo "$edges_json" | jq \
            --arg from "$node_id" \
            --arg to_path "$ns" \
            --arg rel "uses" \
            '. + [{"from": $from, "to_path": $to_path, "rel": $rel, "source": "static"}]')
        fi
      done < "$file"
      ;;
  esac

  echo "$edges_json"
}

# ─── render memory.md ─────────────────────────────────────────────────────────

render_memory_md() {
  local branch_dir="$1"
  local memory_json="${branch_dir}/memory.json"
  local nodes_json="${branch_dir}/nodes.json"
  local edges_json_file="${branch_dir}/edges.json"

  local stack_runtime stack_frontend
  stack_runtime=$(jq -r '.stack.runtime // "unknown"' "$memory_json" 2>/dev/null || echo "unknown")
  stack_frontend=$(jq -r '.stack.frontend // "unknown"' "$memory_json" 2>/dev/null || echo "unknown")

  local output
  output="# DevFlow Memory\n\n"
  output+="## Stack\n\n"
  output+="- Runtime: ${stack_runtime}\n"
  output+="- Frontend: ${stack_frontend}\n\n"

  local total_nodes
  total_nodes=$(jq '.nodes | length' "$nodes_json" 2>/dev/null || echo 0)

  output+="## Graph\n\n"

  # Priority order for summary: route, entity, service, contract, others
  # Top 30 nodes in summary section
  local summary_count=0
  local full_section=""
  local in_summary=true

  for node_type in route entity service contract; do
    while IFS= read -r node_line; do
      [[ -z "$node_line" ]] && continue
      local node_id node_intent node_stale
      node_id=$(echo "$node_line" | jq -r '.id')
      node_intent=$(echo "$node_line" | jq -r '.intent // ""')
      node_stale=$(echo "$node_line" | jq -r '.stale // false')

      local stale_marker=""
      [[ "$node_stale" = "deleted" ]] && stale_marker=" [DELETED]"
      [[ "$node_stale" = "aged" ]] && stale_marker=" [UNVERIFIED]"

      local line="${node_id}${stale_marker}: ${node_intent}"

      if $in_summary && [[ $summary_count -lt 30 ]]; then
        output+="${line}\n"
        ((summary_count++)) || true
      else
        in_summary=false
        full_section+="${line}\n"
      fi
    done < <(jq -c --arg t "$node_type" '.nodes[] | select(.type == $t)' "$nodes_json" 2>/dev/null || true)
  done

  # Any remaining types
  while IFS= read -r node_line; do
    [[ -z "$node_line" ]] && continue
    local node_id node_intent node_stale
    node_id=$(echo "$node_line" | jq -r '.id')
    node_intent=$(echo "$node_line" | jq -r '.intent // ""')
    node_stale=$(echo "$node_line" | jq -r '.stale // false')
    local stale_marker=""
    [[ "$node_stale" = "deleted" ]] && stale_marker=" [DELETED]"
    [[ "$node_stale" = "aged" ]] && stale_marker=" [UNVERIFIED]"
    local line="${node_id}${stale_marker}: ${node_intent}"
    if $in_summary && [[ $summary_count -lt 30 ]]; then
      output+="${line}\n"
      ((summary_count++)) || true
    else
      in_summary=false
      full_section+="${line}\n"
    fi
  done < <(jq -c '.nodes[] | select(.type != "route" and .type != "entity" and .type != "service" and .type != "contract")' "$nodes_json" 2>/dev/null || true)

  if [[ -n "$full_section" ]]; then
    output+="\n<!-- full-graph -->\n${full_section}"
  fi

  printf '%b' "$output"
}

# ─── AI batch ─────────────────────────────────────────────────────────────────

ai_batch() {
  local files_json="$1"   # JSON array of {path, type, content}
  local mock_file="${DEVFLOW_AI_MOCK_FILE:-}"

  if [[ "${DEVFLOW_AI_MOCK:-}" = "1" ]] && [[ -n "$mock_file" ]] && [[ -f "$mock_file" ]]; then
    jq '.batch' "$mock_file"
    return 0
  fi

  # Real API call placeholder — emit empty array on no API key
  err "Warning: DEVFLOW_AI_MOCK not set and no Claude API implementation yet — writing nodes without intent"
  echo "[]"
}

# ─── patch nodes ──────────────────────────────────────────────────────────────

patch_nodes() {
  local nodes_file="$1"
  local ai_results="$2"    # JSON array from ai_batch
  local head_sha="$3"

  local existing="[]"
  [[ -f "$nodes_file" ]] && existing=$(jq '.nodes' "$nodes_file")

  # For each AI result: upsert by id, preserve confidence:manual
  local updated
  updated=$(jq -n \
    --argjson existing "$existing" \
    --argjson ai "$ai_results" \
    --arg sha "$head_sha" \
    '
    ($existing | map({(.id): .}) | add // {}) as $existing_map |
    ($ai | map(
      . as $r |
      ($r.path | gsub("\\.(?=[^.]*$)"; "") | gsub("/"; ".")) as $slug |
      ($r | if .type then .type else "unknown" end) as $t |
      "\($t):\($slug)" as $id |
      if ($existing_map[$id] // null) != null and ($existing_map[$id].confidence == "manual") then
        $existing_map[$id]
      else
        {
          id: $id,
          name: ($r.path | split("/") | last | gsub("\\..*$"; "")),
          type: $t,
          file: $r.path,
          intent: ($r.intent // ""),
          confidence: ($r.confidence // "ai"),
          last_seen: $sha
        }
      end
    )) as $new_nodes |
    # Merge: start with existing, overlay with new
    ($existing | map(select(
      . as $e |
      ($new_nodes | map(select(.id == $e.id)) | length) == 0
    ))) + $new_nodes
    ')

  echo "$updated"
}

# ─── patch edges ──────────────────────────────────────────────────────────────

patch_edges() {
  local edges_file="$1"
  local static_edges_json="$2"   # array of {from, to_path, rel, source}
  local ai_edges_json="$3"       # array of {from, to_path, rel}
  local nodes_json="$4"          # path to nodes.json for ID resolution
  local head_sha="$5"

  local existing_edges="[]"
  [[ -f "$edges_file" ]] && existing_edges=$(jq '.edges' "$edges_file")

  # Resolve to_path to node id using nodes.json
  local all_new_edges
  all_new_edges=$(jq -n \
    --argjson static_e "$static_edges_json" \
    --argjson ai_e "$ai_edges_json" \
    --slurpfile nodes_arr "$nodes_json" \
    --arg sha "$head_sha" \
    '
    ($nodes_arr[0].nodes | map({(.file): .id}) | add // {}) as $file_to_id |
    ($static_e + ($ai_e | map(. + {source: "ai"}))) |
    map(
      . as $e |
      ($file_to_id[$e.to_path] // null) as $to_id |
      if $to_id == null then empty
      else
        {from: $e.from, to: $to_id, rel: $e.rel, source: ($e.source // "ai"), last_seen: $sha}
      end
    ) |
    # Dedup: static wins over ai for same (from, to, rel)
    group_by(.from + "|" + .to + "|" + .rel) |
    map(sort_by(if .source == "static" then 0 else 1 end) | first)
    ')

  # Merge with existing (keep existing that are not in new set)
  jq -n \
    --argjson existing "$existing_edges" \
    --argjson new_e "$all_new_edges" \
    '($existing | map(select(
      . as $ex |
      ($new_e | map(select(.from == $ex.from and .to == $ex.to and .rel == $ex.rel)) | length) == 0
    ))) + $new_e'
}

# ─── staleness sweep ──────────────────────────────────────────────────────────

staleness_sweep() {
  local nodes_json_str="$1"    # JSON string of nodes array
  local edges_json_str="$2"    # JSON string of edges array
  local deleted_files="$3"     # newline-separated list of deleted file paths
  local head_sha="$4"
  local threshold="$5"

  # Hard stale: deleted files
  local updated_nodes
  updated_nodes=$(echo "$nodes_json_str" | jq \
    --arg deleted "$deleted_files" \
    '
    ($deleted | split("\n") | map(select(length > 0))) as $del_list |
    map(if (.file as $f | $del_list | any(. == $f)) then . + {stale: "deleted"} else . end)
    ')

  # Soft stale: not seen in N commits — use last_seen field
  # Count commits since last_seen SHA for each node
  local nodes_count
  nodes_count=$(echo "$updated_nodes" | jq 'length')
  for ((i=0; i<nodes_count; i++)); do
    local node_stale node_last_seen node_file
    node_stale=$(echo "$updated_nodes" | jq -r ".[$i].stale // false")
    [[ "$node_stale" = "deleted" ]] && continue
    node_last_seen=$(echo "$updated_nodes" | jq -r ".[$i].last_seen // \"\"")
    node_file=$(echo "$updated_nodes" | jq -r ".[$i].file")
    if [[ -n "$node_last_seen" && "$node_last_seen" != "null" ]]; then
      local commit_count
      commit_count=$(git log --oneline "${node_last_seen}..HEAD" -- "$node_file" 2>/dev/null | wc -l | tr -d ' ')
      if [[ "$commit_count" -ge "$threshold" ]]; then
        updated_nodes=$(echo "$updated_nodes" | jq \
          --argjson idx "$i" \
          '.[$idx] |= . + {stale: "aged"}')
      fi
    fi
  done

  # Edge staleness: inherit from endpoints
  local updated_edges
  updated_edges=$(jq -n \
    --argjson edges "$edges_json_str" \
    --argjson nodes "$updated_nodes" \
    '
    ($nodes | map({(.id): (.stale // false)}) | add // {}) as $stale_map |
    $edges | map(
      . as $e |
      ($stale_map[$e.from] // false) as $from_stale |
      ($stale_map[$e.to] // false) as $to_stale |
      if $from_stale == "deleted" or $to_stale == "deleted" then . + {stale: "deleted"}
      elif $from_stale == "aged" or $to_stale == "aged" then . + {stale: "aged"}
      else .
      end
    )')

  # Return as two-element JSON array: [nodes, edges]
  jq -n --argjson nodes "$updated_nodes" --argjson edges "$updated_edges" '[$nodes, $edges]'
}

# ─── prune graph ──────────────────────────────────────────────────────────────

prune_graph() {
  local nodes_json_str="$1"
  local edges_json_str="$2"
  local max_nodes="$3"
  local prune_min_age="$4"
  local head_sha="$5"

  local count
  count=$(echo "$nodes_json_str" | jq 'length')
  if [[ "$count" -le "$max_nodes" ]]; then
    jq -n --argjson nodes "$nodes_json_str" --argjson edges "$edges_json_str" '[$nodes, $edges]'
    return
  fi

  # Remove stale nodes older than prune_min_age_commits with no inbound edges
  local pruned_nodes pruned_ids
  pruned_nodes=$(jq -n \
    --argjson nodes "$nodes_json_str" \
    --argjson edges "$edges_json_str" \
    --argjson max "$max_nodes" \
    --argjson min_age "$prune_min_age" \
    --arg head "$head_sha" \
    '
    ($edges | map(.to) | unique) as $has_inbound |
    $nodes | sort_by(.last_seen) |
    reduce .[] as $n (
      {keep: [], drop: []};
      if ((.keep | length) + (.drop | length)) < ($nodes | length) then
        if ($n.stale == "deleted" or $n.stale == "aged") and
           ($has_inbound | any(. == $n.id) | not) then
          . + {drop: (.drop + [$n])}
        else
          . + {keep: (.keep + [$n])}
        end
      else . end
    ) |
    .keep
    ')

  pruned_ids=$(jq -n \
    --argjson all "$nodes_json_str" \
    --argjson kept "$pruned_nodes" \
    '($all | map(.id)) - ($kept | map(.id))')

  local pruned_edges
  pruned_edges=$(jq -n \
    --argjson edges "$edges_json_str" \
    --argjson dropped_ids "$pruned_ids" \
    '$edges | map(select(.from as $f | $dropped_ids | any(. == $f) | not)) |
              map(select(.to as $t | $dropped_ids | any(. == $t) | not))')

  jq -n --argjson nodes "$pruned_nodes" --argjson edges "$pruned_edges" '[$nodes, $edges]'
}

# ─── cmd_sync ────────────────────────────────────────────────────────────────

cmd_sync() {
  local force=false
  local all_flag=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=true; shift ;;
      --all)   all_flag=true; shift ;;
      *) shift ;;
    esac
  done

  check_prereqs
  [[ ! -d "$DEVFLOW_DIR" ]] && exit 0  # CI mode

  acquire_lock

  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  local branch_canon
  branch_canon=$(canonicalize_branch "$branch")
  local branch_dir="${DEVFLOW_DIR}/branches/${branch_canon}"
  local active_dir="${DEVFLOW_DIR}/active"
  local config_file="${DEVFLOW_DIR}/config.json"
  local head_sha
  head_sha=$(git rev-parse HEAD)

  [[ ! -f "$config_file" ]] && exit 0  # CI mode: no config

  # Read config
  local last_synced classifiers max_files threshold
  last_synced=$(jq -r '.last_synced // ""' "$config_file")
  classifiers=$(jq -c '.classifiers // []' "$config_file")
  max_files=$(jq -r '.graph_limits.max_files_per_sync // 200' "$config_file")
  threshold=$(jq -r '.edge_staleness_threshold // 30' "$config_file")

  # Set dirty:true
  local cfg_content
  cfg_content=$(jq '. + {dirty: true}' "$config_file")
  atomic_write "$config_file" "$cfg_content"

  # Get changed files
  local changed_files=()
  local deleted_files=""
  if $force || [[ -z "$last_synced" ]]; then
    mapfile -t changed_files < <(git ls-files)
    deleted_files=""
  else
    mapfile -t changed_files < <(git diff --name-only --diff-filter=ACMR "${last_synced}..HEAD" 2>/dev/null || true)
    deleted_files=$(git diff --name-only --diff-filter=D "${last_synced}..HEAD" 2>/dev/null || true)
  fi

  # Apply large-repo cap (unless --all)
  local total_files="${#changed_files[@]}"
  if ! $all_flag && [[ "$total_files" -gt "$max_files" ]]; then
    err "Large sync: ${total_files} files changed, capped at ${max_files} — run df-sync --force --all to process all files"
    # Sort by priority: route, entity, service, contract, others
    local prioritized=()
    for ptype in route entity service contract; do
      for f in "${changed_files[@]}"; do
        local t
        t=$(classify_file "$f" "$classifiers")
        [[ "$t" = "$ptype" ]] && prioritized+=("$f")
      done
    done
    for f in "${changed_files[@]}"; do
      local t
      t=$(classify_file "$f" "$classifiers")
      if [[ "$t" != "route" && "$t" != "entity" && "$t" != "service" && "$t" != "contract" ]]; then
        prioritized+=("$f")
      fi
    done
    changed_files=("${prioritized[@]:0:$max_files}")
  fi

  # Load existing nodes/edges
  local nodes_json edges_json
  nodes_json=$(jq '.nodes // []' "${active_dir}/nodes.json" 2>/dev/null || echo "[]")
  edges_json=$(jq '.edges // []' "${active_dir}/edges.json" 2>/dev/null || echo "[]")

  # Per-file: classify + static edges
  local all_static_edges="[]"
  local files_for_ai="[]"

  for f in "${changed_files[@]}"; do
    [[ -z "$f" ]] && continue
    local ftype
    ftype=$(classify_file "$f" "$classifiers")
    [[ "$ftype" = "architecture" || "$ftype" = "conventions" ]] && continue
    [[ -z "$ftype" ]] && ftype="unknown"

    local node_id
    node_id=$(file_to_node_id "$f" "$ftype")

    # Static edges
    local file_edges
    file_edges=$(static_edges "$f" "$node_id")
    all_static_edges=$(jq -n --argjson a "$all_static_edges" --argjson b "$file_edges" '$a + $b')

    # Prepare for AI batch: send first 20 lines for new nodes, diff for re-inferred
    local existing_intent
    existing_intent=$(echo "$nodes_json" | jq -r --arg id "$node_id" '.[] | select(.id == $id) | .intent // ""')

    # Check if re-inference needed: file changed >30 lines
    local lines_changed=0
    if [[ -n "$last_synced" ]] && ! $force; then
      lines_changed=$(git diff --stat "${last_synced}..HEAD" -- "$f" 2>/dev/null | grep -oP '\d+(?= insertion)' | head -1 || echo 0)
      lines_changed="${lines_changed:-0}"
    fi

    local content
    if [[ -z "$existing_intent" ]] || [[ "$lines_changed" -gt 30 ]] || $force; then
      # Check if comment-only change
      local is_comment_only=true
      if [[ -n "$last_synced" ]] && ! $force && [[ "$lines_changed" -gt 0 ]]; then
        while IFS= read -r dline; do
          if [[ "$dline" =~ ^\+[^+] ]] && ! [[ "$dline" =~ ^\+[[:space:]]*(//|/\*|\*|#|assert|expect|should) ]]; then
            is_comment_only=false
            break
          fi
        done < <(git diff "${last_synced}..HEAD" -- "$f" 2>/dev/null || true)
      else
        is_comment_only=false
      fi

      if ! $is_comment_only; then
        if [[ "$lines_changed" -gt 30 ]] && [[ -n "$last_synced" ]] && ! $force; then
          content=$(git diff "${last_synced}..HEAD" -- "$f" 2>/dev/null | head -100 || true)
        else
          content=$(head -20 "$f" 2>/dev/null || true)
        fi
        files_for_ai=$(echo "$files_for_ai" | jq \
          --arg path "$f" --arg type "$ftype" --arg content "$content" \
          '. + [{"path": $path, "type": $type, "content": $content}]')
      fi
    fi
  done

  # Staleness sweep
  local sweep_result
  sweep_result=$(staleness_sweep "$nodes_json" "$edges_json" "$deleted_files" "$head_sha" "$threshold")
  nodes_json=$(echo "$sweep_result" | jq '.[0]')
  edges_json=$(echo "$sweep_result" | jq '.[1]')

  # AI batch
  local ai_results
  ai_results=$(ai_batch "$files_for_ai")

  # Extract AI edges
  local ai_edges="[]"
  if [[ "$(echo "$ai_results" | jq 'length')" -gt 0 ]]; then
    ai_edges=$(echo "$ai_results" | jq '[.[] | .edges // [] | .[] | {from: "placeholder", to_path: .to_file, rel: .rel}]')
    # Fix from: use path→node_id
    ai_edges=$(jq -n \
      --argjson results "$ai_results" \
      '[.results[] | . as $r | ($r.edges // []) | .[] | {
        from: ($r.path | gsub("\\.(?=[^.]*$)"; "") | gsub("/"; ".") | "\($r.type // "unknown"):\(.)"),
        to_path: .to_file,
        rel: .rel
      }]' <<< "{\"results\": $ai_results}")
  fi

  # Patch nodes
  local new_nodes_arr
  new_nodes_arr=$(patch_nodes "${active_dir}/nodes.json" "$ai_results" "$head_sha")
  nodes_json="$new_nodes_arr"

  # Patch edges
  local new_edges_arr
  new_edges_arr=$(patch_edges "${active_dir}/edges.json" "$all_static_edges" "$ai_edges" \
    <(echo "{\"schema_version\":1,\"nodes\":$(echo "$nodes_json")}") "$head_sha")
  # patch_edges needs a file, use temp
  local tmp_nodes
  tmp_nodes=$(mktemp)
  echo "{\"schema_version\":1,\"nodes\":${nodes_json}}" > "$tmp_nodes"
  new_edges_arr=$(patch_edges "${active_dir}/edges.json" "$all_static_edges" "$ai_edges" "$tmp_nodes" "$head_sha")
  rm -f "$tmp_nodes"
  edges_json="$new_edges_arr"

  # Prune graph
  local max_nodes prune_age
  max_nodes=$(jq -r '.graph_limits.max_nodes // 2000' "$config_file")
  prune_age=$(jq -r '.graph_limits.prune_min_age_commits // 90' "$config_file")
  local prune_result
  prune_result=$(prune_graph "$nodes_json" "$edges_json" "$max_nodes" "$prune_age" "$head_sha")
  nodes_json=$(echo "$prune_result" | jq '.[0]')
  edges_json=$(echo "$prune_result" | jq '.[1]')

  # Write all files atomically
  atomic_write "${branch_dir}/nodes.json" \
    "$(jq -n --argjson n "$nodes_json" '{schema_version:1, nodes:$n}')"
  atomic_write "${branch_dir}/edges.json" \
    "$(jq -n --argjson e "$edges_json" '{schema_version:1, edges:$e}')"

  # Render memory.md
  local md
  md=$(render_memory_md "$branch_dir")
  atomic_write "${branch_dir}/memory.md" "$md"

  # Update config: dirty:false, last_synced
  cfg_content=$(jq --arg sha "$head_sha" '. + {dirty: false, last_synced: $sha}' "$config_file")
  atomic_write "$config_file" "$cfg_content"
}

# ─── cmd_branch_switch ───────────────────────────────────────────────────────

cmd_branch_switch() {
  check_prereqs
  [[ ! -d "$DEVFLOW_DIR" ]] && exit 0  # CI mode

  acquire_lock

  local new_branch
  new_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
  local new_canon
  new_canon=$(canonicalize_branch "$new_branch")
  local new_branch_dir="${DEVFLOW_DIR}/branches/${new_canon}"
  local config_file="${DEVFLOW_DIR}/config.json"

  # Swap active symlink
  mkdir -p "$new_branch_dir"
  ln -sfn "branches/${new_canon}" "${DEVFLOW_DIR}/active"

  # Bootstrap new branch if no memory exists
  if [[ ! -f "${new_branch_dir}/nodes.json" ]]; then
    # Find nearest branch
    local nearest_canon=""
    local nearest_distance=999999
    for branch_dir in "${DEVFLOW_DIR}"/branches/*/; do
      local bcanon
      bcanon=$(basename "$branch_dir")
      [[ "$bcanon" = "$new_canon" ]] && continue
      [[ ! -f "${branch_dir}nodes.json" ]] && continue
      # Use commit count as proxy for distance
      local bname="${bcanon//__//}"
      local dist
      dist=$(git rev-list --count "${bname}..HEAD" 2>/dev/null || echo 999999)
      if [[ "$dist" -lt "$nearest_distance" ]]; then
        nearest_distance="$dist"
        nearest_canon="$bcanon"
      fi
    done

    if [[ -n "$nearest_canon" ]]; then
      cp -r "${DEVFLOW_DIR}/branches/${nearest_canon}/." "$new_branch_dir/"
      local divergence_sha
      divergence_sha=$(git merge-base "${nearest_canon//__//}" HEAD 2>/dev/null || git rev-parse HEAD)
      local cfg_content
      cfg_content=$(jq --arg sha "$divergence_sha" '. + {last_synced: $sha}' "$config_file")
      atomic_write "$config_file" "$cfg_content"
    else
      # No branches: init empty
      echo '{"schema_version":1,"nodes":[]}' > "${new_branch_dir}/nodes.json"
      echo '{"schema_version":1,"edges":[]}' > "${new_branch_dir}/edges.json"
      echo '# DevFlow Memory' > "${new_branch_dir}/memory.md"
    fi
  fi

  # Conflict detection
  local prev_nodes_file=""
  # Find prev branch nodes by checking all branches except current
  for branch_dir in "${DEVFLOW_DIR}"/branches/*/; do
    local bcanon
    bcanon=$(basename "$branch_dir")
    [[ "$bcanon" = "$new_canon" ]] && continue
    [[ -f "${branch_dir}nodes.json" ]] && prev_nodes_file="${branch_dir}nodes.json" && break
  done

  local conflicts="[]"
  if [[ -n "$prev_nodes_file" ]]; then
    conflicts=$(jq -n \
      --slurpfile new_nodes "${new_branch_dir}/nodes.json" \
      --slurpfile prev_nodes "$prev_nodes_file" \
      '
      ($new_nodes[0].nodes | map({(.id): .intent}) | add // {}) as $new_map |
      ($prev_nodes[0].nodes | map({(.id): .intent}) | add // {}) as $prev_map |
      [$new_map | to_entries[] |
        . as $entry |
        if ($prev_map[$entry.key] != null) and
           ($prev_map[$entry.key] != $entry.value) and
           ($entry.value | length > 0) and
           ($prev_map[$entry.key] | length > 0)
        then {id: $entry.key, conflict: "intent",
              branch_a: $entry.value, branch_b: $prev_map[$entry.key]}
        else empty end
      ]')
  fi

  local conflicts_file="${new_branch_dir}/graph_conflicts.json"
  local n_conflicts
  n_conflicts=$(echo "$conflicts" | jq 'length')
  if [[ "$n_conflicts" -gt 0 ]]; then
    atomic_write "$conflicts_file" \
      "$(jq -n --argjson sha "\"$(git rev-parse HEAD)\"" --argjson c "$conflicts" \
        '{generated_at: $sha, nodes: $c, edges: []}')"
  else
    rm -f "$conflicts_file"
  fi

  # Stale branch cleanup
  local git_branches
  mapfile -t git_branches < <(git branch --format='%(refname:short)' | sed 's|/|__|g')
  for branch_dir in "${DEVFLOW_DIR}"/branches/*/; do
    local bcanon
    bcanon=$(basename "$branch_dir")
    local found=false
    for gb in "${git_branches[@]}"; do
      [[ "$gb" = "$bcanon" ]] && found=true && break
    done
    $found || rm -rf "$branch_dir"
  done

  # Run sync on new branch
  cmd_sync
}

# ─── cmd_version ─────────────────────────────────────────────────────────────

cmd_version() {
  echo "DevFlow $DEVFLOW_VERSION"
  exit 0
}

# ─── dispatch ─────────────────────────────────────────────────────────────────

case "${1:-}" in
  --version)        cmd_version ;;
  --branch-switch)  cmd_branch_switch ;;
  --force)
    shift
    if [[ "${1:-}" = "--all" ]]; then
      cmd_sync --force --all
    else
      cmd_sync --force
    fi
    ;;
  "")               cmd_sync ;;
  *)
    err "Unknown command: $1. Usage: df-sync [--version|--force [--all]|--branch-switch]"
    exit 1
    ;;
esac
```

- [ ] **Step 2: Run shellcheck**

```bash
shellcheck bin/df-sync
```

Expected: exit 0 with no warnings. Fix any issues before proceeding.

- [ ] **Step 3: Run bats against the stub (some tests should pass now)**

```bash
bats tests/df-sync.bats
```

Expected: `--version`, `CI mode`, and `not a git repo` tests pass. Others still fail (no `.devflow/` setup in `_init_repo` test path yet).

- [ ] **Step 4: Commit**

```bash
git add bin/df-sync
git commit -m "feat: implement df-sync core (version, prereqs, lock, CI mode, sync, branch-switch)"
```

---

## Task 4: Run Full Test Suite and Fix Failures

**Files:**
- Modify: `bin/df-sync` (bug fixes)
- Modify: `tests/df-sync.bats` (fix test setup issues, not logic)

- [ ] **Step 1: Run the full test suite**

```bash
bats tests/df-sync.bats
```

Expected: some tests pass, some fail. Note which fail and why.

- [ ] **Step 2: Run shellcheck**

```bash
shellcheck bin/df-sync
```

Expected: exit 0. Fix any warnings before proceeding.

- [ ] **Step 3: Fix failures**

For each failing test:
1. Read the failure output carefully
2. Identify whether it's a script bug or a test setup issue
3. Fix the script (preferred) or the test setup (only if the test itself is wrong)
4. Re-run the specific test: `bats tests/df-sync.bats --filter "<test name>"`

Common issues to look for:
- `patch_edges` receives a process substitution but bash `<(...)` doesn't work as a filename arg in all contexts — use a temp file
- `jq` path expressions with `gsub` on node ID formula — verify the formula produces correct IDs
- `staleness_sweep` loop using `((i++))` — needs `|| true` after arithmetic to avoid `set -e` exit
- `render_memory_md` `printf '%b'` expanding backslash sequences in node intents — if node intent contains `\n`, use a different approach

- [ ] **Step 4: Run full suite until all pass**

```bash
bats tests/df-sync.bats
```

Expected: all 22 tests pass.

- [ ] **Step 5: Commit**

```bash
git add bin/df-sync tests/df-sync.bats
git commit -m "fix: pass all df-sync bats tests"
```

---

## Task 5: Write `skills/mem-sync/SKILL.md`

**Files:**
- Create: `skills/mem-sync/SKILL.md`

- [ ] **Step 1: Write the skill file**

```markdown
# Skill: mem-sync

# DevFlow Memory Sync

Verify graph memory is current before the session begins. Invoked automatically by the post-commit hook via `df-sync`. Also safe to call manually before any skill that reads memory.

**When to invoke:** Before any skill that reads `.devflow/active/memory.md`, `nodes.json`, or `edges.json`.

---

## Flow

### Step 1 — Check staleness

Read `.devflow/config.json`. Extract `last_synced` and `dirty`.

Run:
```bash
git rev-parse HEAD
```

- If `last_synced == HEAD` and `dirty == false`: memory is current. Exit — nothing to do.
- If `dirty == true` or `last_synced != HEAD`: proceed to Step 2.

### Step 2 — Run df-sync

Run:
```bash
df-sync
```

Capture exit code.

### Step 3 — Verify

Check all required files exist and are valid JSON:
- `.devflow/active/memory.json`
- `.devflow/active/nodes.json`
- `.devflow/active/edges.json`

Confirm `config.json` has:
- `dirty == false`
- `last_synced == HEAD SHA` (re-read HEAD after sync)

If all checks pass: exit success.

### Step 4 — Retry or fail

If Step 3 fails:
- Run `df-sync` once more.
- Re-run the Step 3 checks.
- If still failing: output `[DevFlow] sync failed — memory may be stale` and exit 1.

---

## Error Reference

| Scenario | Response |
|---|---|
| `df-sync` exits non-zero | Retry once (Step 4); fail loudly if still failing |
| `nodes.json` invalid JSON | Log file name, proceed to retry |
| `dirty: true` after sync | Retry once |
| `last_synced != HEAD` after sync | Retry once |
| Still failing after retry | Exit 1 — `[DevFlow] sync failed — memory may be stale` |

---

## Notes

- Never silently continue with stale memory. Always exit 1 if sync cannot be verified.
- If `df-sync` is not on PATH, tell the developer to install DevFlow.
- The post-commit hook calls `df-sync` directly; `mem-sync` is for AI agents to call before reading memory.
```

- [ ] **Step 2: Verify the file is well-formed markdown**

```bash
wc -l skills/mem-sync/SKILL.md
```

Expected: ~60+ lines, no errors.

- [ ] **Step 3: Commit**

```bash
git add skills/mem-sync/SKILL.md
git commit -m "feat: add mem-sync skill"
```

---

## Task 6: End-to-End Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full bats suite**

```bash
bats tests/df-sync.bats
```

Expected: all 22 tests pass.

- [ ] **Step 2: Run shellcheck**

```bash
shellcheck bin/df-sync
```

Expected: exit 0, no warnings.

- [ ] **Step 3: End-to-end in the DevFlow repo itself**

```bash
cd /Volumes/ReydoSSD/SourceCode/Development-Flow
df-init --scan | jq .
```

Then init the repo with mock mode and run a sync:

```bash
# Reinitialise DevFlow on this repo (if not already done)
# Then make a small commit and verify df-sync updates nodes.json
echo "# test" >> README.md
git add README.md && git commit -m "test: trigger df-sync"
df-sync
jq '.last_synced' .devflow/config.json   # should match HEAD SHA
cat .devflow/active/memory.md            # should show graph nodes
```

- [ ] **Step 4: End-to-end in a second repo**

```bash
# Create a fresh temp repo
tmpdir=$(mktemp -d)
cd "$tmpdir"
git init -b main
echo "class Foo {}" > Foo.cs
git add . && git commit -m "initial"

# Init devflow (using DEVFLOW_AI_MOCK=1)
DEVFLOW_AI_MOCK=1 df-init --scan | jq .
# Write mock memory patch + run --write-memory, then:
df-sync
cat .devflow/active/memory.md

cd -
rm -rf "$tmpdir"
```

Expected: no errors, `memory.md` shows at least one node, `config.json` has `dirty: false`.

- [ ] **Step 5: Final commit (if any files changed)**

```bash
git status
# Only commit if there are actual changes
```

---

## Definition of Done

- [ ] `bin/df-sync` passes `shellcheck` with zero warnings
- [ ] All 22 bats tests in `tests/df-sync.bats` pass
- [ ] `DEVFLOW_AI_MOCK=1` works end-to-end
- [ ] `skills/mem-sync/SKILL.md` written
- [ ] Works end-to-end: commit in a real repo → `df-sync` → `nodes.json` + `memory.md` updated

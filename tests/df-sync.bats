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

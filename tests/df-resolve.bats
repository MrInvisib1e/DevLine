#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────

setup() {
  export REPO
  REPO="$(mktemp -d)"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "initial" --quiet)
  mkdir -p "$REPO/.devflow/branches/main"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-memory/nodes.json" "$REPO/.devflow/branches/main/nodes.json"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-graph-conflicts.json" "$REPO/.devflow/branches/main/graph_conflicts.json"
  ln -sfn "branches/main" "$REPO/.devflow/active"
  export DF_RESOLVE="$BATS_TEST_DIRNAME/../bin/df-resolve"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$REPO"
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "df-resolve --version prints DevFlow version and exits 0" {
  run "$DF_RESOLVE" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── --list ────────────────────────────────────────────────────────────────────

@test "--list: prints all conflicted node IDs" {
  run bash -c "cd '$REPO' && '$DF_RESOLVE' --list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "entity:Entities.Comment" ]]
  [[ "$output" =~ "service:Services.CommentService" ]]
}

@test "--list: no conflicts file prints 'no conflicts' message and exits 0" {
  rm "$REPO/.devflow/branches/main/graph_conflicts.json"
  run bash -c "cd '$REPO' && '$DF_RESOLVE' --list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No conflicts" ]] || [[ "$output" =~ "no conflicts" ]]
}

# ─── resolve A/B/W choices ────────────────────────────────────────────────────

@test "accept A: sets node intent to branch_a value in nodes.json" {
  run bash -c "cd '$REPO' && '$DF_RESOLVE' --accept a 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
  run jq -r '.nodes[] | select(.id=="entity:Entities.Comment") | .intent' "$REPO/.devflow/branches/main/nodes.json"
  [ "$output" = "Soft-deletable content unit" ]
}

@test "accept B: sets node intent to branch_b value in nodes.json" {
  run bash -c "cd '$REPO' && '$DF_RESOLVE' --accept b 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
  run jq -r '.nodes[] | select(.id=="entity:Entities.Comment") | .intent' "$REPO/.devflow/branches/main/nodes.json"
  [ "$output" = "Append-only comment log" ]
}

@test "accept A: sets confidence to manual in nodes.json" {
  run bash -c "cd '$REPO' && '$DF_RESOLVE' --accept a 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
  run jq -r '.nodes[] | select(.id=="entity:Entities.Comment") | .confidence' "$REPO/.devflow/branches/main/nodes.json"
  [ "$output" = "manual" ]
}

@test "accept: removes resolved conflict from graph_conflicts.json" {
  bash -c "cd '$REPO' && '$DF_RESOLVE' --accept a 'entity:Entities.Comment'"
  run jq '[.conflicts[] | select(.node_id=="entity:Entities.Comment")] | length' "$REPO/.devflow/branches/main/graph_conflicts.json"
  [ "$output" = "0" ]
}

@test "accept: deletes graph_conflicts.json when all conflicts resolved" {
  bash -c "cd '$REPO' && '$DF_RESOLVE' --accept a 'entity:Entities.Comment'"
  bash -c "cd '$REPO' && '$DF_RESOLVE' --accept a 'service:Services.CommentService'"
  [ ! -f "$REPO/.devflow/branches/main/graph_conflicts.json" ]
}

@test "unknown node ID: exits 1 with message" {
  run bash -c "cd '$REPO' && '$DF_RESOLVE' --accept a 'entity:Nonexistent' 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

# ─── --rewrite-intent ─────────────────────────────────────────────────────────

@test "--rewrite-intent: overwrites intent and sets confidence to manual" {
  run bash -c "cd '$REPO' && '$DF_RESOLVE' --rewrite-intent 'entity:Entities.Comment' 'Never delete — hide only'"
  [ "$status" -eq 0 ]
  run jq -r '.nodes[] | select(.id=="entity:Entities.Comment") | .intent' "$REPO/.devflow/branches/main/nodes.json"
  [ "$output" = "Never delete — hide only" ]
  run jq -r '.nodes[] | select(.id=="entity:Entities.Comment") | .confidence' "$REPO/.devflow/branches/main/nodes.json"
  [ "$output" = "manual" ]
}

@test "--rewrite-intent --auto: clears intent and sets confidence to ai" {
  # First set it to manual
  bash -c "cd '$REPO' && '$DF_RESOLVE' --rewrite-intent 'entity:Entities.Comment' 'Never delete'"
  # Then revert to AI-managed
  run bash -c "cd '$REPO' && '$DF_RESOLVE' --rewrite-intent 'entity:Entities.Comment' --auto"
  [ "$status" -eq 0 ]
  run jq -r '.nodes[] | select(.id=="entity:Entities.Comment") | .confidence' "$REPO/.devflow/branches/main/nodes.json"
  [ "$output" = "ai" ]
  run jq -r '.nodes[] | select(.id=="entity:Entities.Comment") | .intent // "null"' "$REPO/.devflow/branches/main/nodes.json"
  [ "$output" = "null" ]
}

@test "--rewrite-intent: unknown node ID exits 1 with message" {
  run bash -c "cd '$REPO' && '$DF_RESOLVE' --rewrite-intent 'entity:Nonexistent' 'some intent' 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

# ─── error paths ───────────────────────────────────────────────────────────────

@test "not a git repo: exits 1 with message" {
  tmpdir="$(mktemp -d)"
  run bash -c "cd '$tmpdir' && '$DF_RESOLVE' --list 2>&1"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not a git repo" ]]
}

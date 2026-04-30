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
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'comment' 2>&1"
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
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' 'NonExistent' 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "No memory found" ]]
}

@test "--node exact: resolves exact node ID" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' --node 'entity:Entities.Comment'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Comment" ]]
}

@test "--node not found: prints error and exits 1" {
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' --node 'entity:Nonexistent' 2>&1"
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

@test "node with no inbound edges omits DEPENDED ON BY section" {
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
  run bash -c "cd '$tmpdir' && '$DF_EXPLAIN' Comment 2>&1"
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
  run bash -c "cd '$REPO' && '$DF_EXPLAIN' Comment 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not initialised" ]] || [[ "$output" =~ "not initialized" ]]
}

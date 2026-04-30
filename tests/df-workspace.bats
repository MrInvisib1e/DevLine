#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────

setup() {
  export REPO
  REPO="$(mktemp -d)"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "initial" --quiet)
  mkdir -p "$REPO/.devflow/branches/main"
  # Fake memory.md for sibling repos
  mkdir -p "$REPO/.devflow/branches/main"
  echo "# memory" > "$REPO/.devflow/branches/main/memory.md"
  ln -sfn "branches/main" "$REPO/.devflow/active"

  # Registry dir — isolated per test run
  export DEVFLOW_WORKSPACE_DIR
  DEVFLOW_WORKSPACE_DIR="$(mktemp -d)"

  export DF_WORKSPACE="$BATS_TEST_DIRNAME/../bin/df-workspace"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$REPO" "$DEVFLOW_WORKSPACE_DIR"
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "df-workspace --version prints DevFlow version and exits 0" {
  run "$DF_WORKSPACE" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── add ───────────────────────────────────────────────────────────────────────

@test "add: creates workspace registry file with service entry" {
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  [ "$status" -eq 0 ]
  [ -f "$DEVFLOW_WORKSPACE_DIR/myws.json" ]
  run jq -r '.core' "$DEVFLOW_WORKSPACE_DIR/myws.json"
  [ "$output" = "$REPO" ]
}

@test "add: second add to same workspace appends without overwriting existing" {
  bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' add myws portal /tmp/other"
  run jq -r 'keys | length' "$DEVFLOW_WORKSPACE_DIR/myws.json"
  [ "$output" = "2" ]
  run jq -r '.core' "$DEVFLOW_WORKSPACE_DIR/myws.json"
  [ "$output" = "$REPO" ]
}

# ─── remove ────────────────────────────────────────────────────────────────────

@test "remove: removes a service entry from the workspace" {
  bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' add myws portal /tmp/other"
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' remove myws core"
  [ "$status" -eq 0 ]
  run jq -r '.core // "absent"' "$DEVFLOW_WORKSPACE_DIR/myws.json"
  [ "$output" = "absent" ]
  run jq -r '.portal' "$DEVFLOW_WORKSPACE_DIR/myws.json"
  [ "$output" = "/tmp/other" ]
}

@test "remove: removing non-existent service exits 1 with message" {
  bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' remove myws ghost 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

# ─── list ──────────────────────────────────────────────────────────────────────

@test "list: prints all registered workspaces" {
  bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' add ws1 core '$REPO'"
  bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' add ws2 portal /tmp/other"
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ws1" ]]
  [[ "$output" =~ "ws2" ]]
}

@test "list: prints message when no workspaces registered" {
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No workspaces" ]] || [[ "$output" =~ "no workspaces" ]]
}

# ─── read ──────────────────────────────────────────────────────────────────────

@test "read: returns memory.md content for a registered sibling" {
  # Register REPO itself as sibling "core"
  bash -c "DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' read myws core memory.md"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "memory" ]]
}

@test "read: missing registry prints error and exits 1" {
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' read noexist core memory.md 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not registered" ]]
}

@test "read: sibling path not on disk prints warning and exits 1" {
  # Register a path that does not exist
  echo '{"ghost":"/nonexistent/path"}' > "$DEVFLOW_WORKSPACE_DIR/myws.json"
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' read myws ghost memory.md 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "path not found" ]] || [[ "$output" =~ "not found" ]]
}

@test "read: sibling missing .devflow/ prints warning and exits 1" {
  # A real dir but no .devflow/ inside
  tmpdir="$(mktemp -d)"
  echo "{\"bare\":\"$tmpdir\"}" > "$DEVFLOW_WORKSPACE_DIR/myws.json"
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' read myws bare memory.md 2>&1 || true"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "no .devflow" ]] || [[ "$output" =~ "not initialized" ]] || [[ "$output" =~ "df-init" ]]
}

@test "read: memory.md empty prints warning and exits 1" {
  # Create sibling with an empty memory.md
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/.devflow/branches/main"
  touch "$tmpdir/.devflow/branches/main/memory.md"
  ln -sfn "branches/main" "$tmpdir/.devflow/active"
  echo "{\"empty\":\"$tmpdir\"}" > "$DEVFLOW_WORKSPACE_DIR/myws.json"
  run bash -c "cd '$REPO' && DEVFLOW_WORKSPACE_DIR='$DEVFLOW_WORKSPACE_DIR' '$DF_WORKSPACE' read myws empty memory.md 2>&1 || true"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "empty" ]] || [[ "$output" =~ "unreadable" ]]
}

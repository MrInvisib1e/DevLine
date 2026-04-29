#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────

setup() {
  export REPO
  REPO="$(mktemp -d)"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "initial" --quiet)
  # v4: .devline/ with memory.md directly (no branches/ subdirectory)
  mkdir -p "$REPO/.devline"
  echo "# memory" > "$REPO/.devline/memory.md"

  # Registry dir — isolated per test run
  export DEVLINE_WORKSPACE_DIR
  DEVLINE_WORKSPACE_DIR="$(mktemp -d)"

  export DF_WORKSPACE="$BATS_TEST_DIRNAME/../bin/dl-workspace"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$REPO" "$DEVLINE_WORKSPACE_DIR"
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "dl-workspace --version prints Devline version and exits 0" {
  run "$DF_WORKSPACE" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ Devline ]]
}

# ─── add ───────────────────────────────────────────────────────────────────────

@test "add: creates workspace registry file with service entry" {
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  [ "$status" -eq 0 ]
  [ -f "$DEVLINE_WORKSPACE_DIR/myws.json" ]
  run jq -r '.core' "$DEVLINE_WORKSPACE_DIR/myws.json"
  [ "$output" = "$REPO" ]
}

@test "add: second add to same workspace appends without overwriting existing" {
  bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' add myws portal /tmp/other"
  run jq -r 'keys | length' "$DEVLINE_WORKSPACE_DIR/myws.json"
  [ "$output" = "2" ]
  run jq -r '.core' "$DEVLINE_WORKSPACE_DIR/myws.json"
  [ "$output" = "$REPO" ]
}

# ─── remove ────────────────────────────────────────────────────────────────────

@test "remove: removes a service entry from the workspace" {
  bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' add myws portal /tmp/other"
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' remove myws core"
  [ "$status" -eq 0 ]
  run jq -r '.core // "absent"' "$DEVLINE_WORKSPACE_DIR/myws.json"
  [ "$output" = "absent" ]
  run jq -r '.portal' "$DEVLINE_WORKSPACE_DIR/myws.json"
  [ "$output" = "/tmp/other" ]
}

@test "remove: removing non-existent service exits 1 with message" {
  bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' remove myws ghost 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

# ─── list ──────────────────────────────────────────────────────────────────────

@test "list: prints all registered workspaces" {
  bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' add ws1 core '$REPO'"
  bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' add ws2 portal /tmp/other"
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ws1" ]]
  [[ "$output" =~ "ws2" ]]
}

@test "list: prints message when no workspaces registered" {
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No workspaces" ]] || [[ "$output" =~ "no workspaces" ]]
}

# ─── read ──────────────────────────────────────────────────────────────────────

@test "read: returns memory.md content for a registered sibling" {
  # Register REPO itself as sibling "core"
  bash -c "DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' add myws core '$REPO'"
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' read myws core memory.md"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "memory" ]]
}

@test "read: missing registry prints error and exits 1" {
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' read noexist core memory.md 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not registered" ]]
}

@test "read: sibling path not on disk prints warning and exits 1" {
  # Register a path that does not exist
  echo '{"ghost":"/nonexistent/path"}' > "$DEVLINE_WORKSPACE_DIR/myws.json"
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' read myws ghost memory.md 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "path not found" ]] || [[ "$output" =~ "not found" ]]
}

@test "read: sibling missing .devline/ prints warning and exits 1" {
  # A real dir but no .devline/ inside
  tmpdir="$(mktemp -d)"
  echo "{\"bare\":\"$tmpdir\"}" > "$DEVLINE_WORKSPACE_DIR/myws.json"
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' read myws bare memory.md 2>&1"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "no .devline" ]] || [[ "$output" =~ "not initialized" ]] || [[ "$output" =~ "dl-init" ]]
}

@test "read: memory.md empty prints warning and exits 1" {
  # Create sibling with an empty memory.md (v4: flat .devline/ structure)
  tmpdir="$(mktemp -d)"
  mkdir -p "$tmpdir/.devline"
  touch "$tmpdir/.devline/memory.md"
  echo "{\"empty\":\"$tmpdir\"}" > "$DEVLINE_WORKSPACE_DIR/myws.json"
  run bash -c "cd '$REPO' && DEVLINE_WORKSPACE_DIR='$DEVLINE_WORKSPACE_DIR' '$DF_WORKSPACE' read myws empty memory.md 2>&1"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "empty" ]] || [[ "$output" =~ "unreadable" ]]
}

# ─── create (worktree) ────────────────────────────────────────────────────────

@test "create: creates a git worktree at .devline/worktrees/<branch>" {
  run bash -c "cd '$REPO' && '$DF_WORKSPACE' create feature/test-slice-1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Worktree created" ]]
  [ -d "$REPO/.devline/worktrees/feature/test-slice-1" ]
}

@test "create: exits 1 if worktree already exists" {
  bash -c "cd '$REPO' && '$DF_WORKSPACE' create feature/test-slice-1"
  run bash -c "cd '$REPO' && '$DF_WORKSPACE' create feature/test-slice-1 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "already exists" ]]
}

@test "create: exits 1 with usage if no branch arg given" {
  run bash -c "cd '$REPO' && '$DF_WORKSPACE' create 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage" ]]
}

# ─── worktree-remove ──────────────────────────────────────────────────────────

@test "worktree-remove: removes an existing git worktree and branch" {
  bash -c "cd '$REPO' && '$DF_WORKSPACE' create feature/test-slice-1"
  run bash -c "cd '$REPO' && '$DF_WORKSPACE' worktree-remove feature/test-slice-1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Worktree removed" ]]
  [ ! -d "$REPO/.devline/worktrees/feature/test-slice-1" ]
}

@test "worktree-remove: exits 1 if worktree does not exist" {
  run bash -c "cd '$REPO' && '$DF_WORKSPACE' worktree-remove feature/nonexistent 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

@test "worktree-remove: exits 1 with usage if no branch arg given" {
  run bash -c "cd '$REPO' && '$DF_WORKSPACE' worktree-remove 2>&1"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage" ]]
}

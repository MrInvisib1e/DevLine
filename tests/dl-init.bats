#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────
#
# dl-init v4 tests — MCP-backed initialization
#
# The new dl-init delegates indexing to codebase-memory-mcp and writes:
#   .devline/config.json
#   .devline/memory.md
#
# In tests, codebase-memory-mcp is mocked via DEVLINE_MCP_MOCK=1
# which causes dl-init to write stub files instead of calling the real MCP server.

setup() {
  export REPO
  REPO="$(mktemp -d)"
  cp -r "$BATS_TEST_DIRNAME/fixtures/sample-repo/." "$REPO/"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git add . && git commit -m "initial" --quiet)
  export DF_INIT="$BATS_TEST_DIRNAME/../bin/dl-init"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  export DEVLINE_MCP_MOCK=1
}

teardown() {
  rm -rf "$REPO"
  unset DEVLINE_MCP_MOCK
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "dl-init --version prints Devline version and exits 0" {
  run "$DF_INIT" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ Devline ]]
}

# ─── fresh init ────────────────────────────────────────────────────────────────

@test "fresh init: config.json created" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.devline/config.json" ]
}

@test "fresh init: memory.md created" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  [ "$status" -eq 0 ]
  [ -f "$REPO/.devline/memory.md" ]
}

@test "fresh init: config.json is valid JSON" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  run jq . "$REPO/.devline/config.json"
  [ "$status" -eq 0 ]
}

@test "fresh init: config.json has required fields" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  jq -e '.service' "$REPO/.devline/config.json" > /dev/null
  jq -e '.mode' "$REPO/.devline/config.json" > /dev/null
  jq -e '.stack' "$REPO/.devline/config.json" > /dev/null
  jq -e '.last_synced' "$REPO/.devline/config.json" > /dev/null
  jq -e '.review_checks' "$REPO/.devline/config.json" > /dev/null
  jq -e '.quality_hooks' "$REPO/.devline/config.json" > /dev/null
}

@test "fresh init: mode is 'project' by default" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  run jq -r '.mode' "$REPO/.devline/config.json"
  [ "$output" = "project" ]
}

@test "fresh init: last_synced matches HEAD SHA" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  head_sha=$(cd "$REPO" && git rev-parse HEAD)
  run jq -r '.last_synced' "$REPO/.devline/config.json"
  [ "$output" = "$head_sha" ]
}

@test "fresh init: stack.runtime auto-detected (dotnet from fixture)" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  run jq -r '.stack.runtime' "$REPO/.devline/config.json"
  # fixture has both Program.cs (dotnet) and vite.config.ts (sveltekit)
  [[ "$output" =~ "dotnet" ]] || [[ "$output" =~ "nodejs" ]]
}

@test "fresh init: review_checks array is non-empty" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  run jq -e 'if (.review_checks | length) > 0 then true else false end' "$REPO/.devline/config.json"
  [ "$status" -eq 0 ]
}


# ─── No branches/ directory in v4 ─────────────────────────────────────────────

@test "v4: no branches/ directory created (single memory.md)" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  [ ! -d "$REPO/.devline/branches" ]
}

@test "v4: no active symlink created (not needed in v4)" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  [ ! -L "$REPO/.devline/active" ]
}

# ─── Re-init ──────────────────────────────────────────────────────────────────

@test "re-init: last_synced updated on second run" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  # Make a new commit
  (cd "$REPO" && touch newfile.txt && git add newfile.txt && git commit -m "second" --quiet)
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  new_sha=$(cd "$REPO" && git rev-parse HEAD)
  run jq -r '.last_synced' "$REPO/.devline/config.json"
  [ "$output" = "$new_sha" ]
}

@test "re-init: config.json still valid JSON after second run" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  run jq . "$REPO/.devline/config.json"
  [ "$status" -eq 0 ]
}


# ─── --reset ──────────────────────────────────────────────────────────────────

@test "--reset: exits 0" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT' --reset"
  [ "$status" -eq 0 ]
}

@test "--reset: .devline/ wiped (or memory.md removed)" {
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT' --reset"
  # After reset, memory.md should not exist until re-init
  [ ! -f "$REPO/.devline/memory.md" ]
}

# ─── orchestrator mode ────────────────────────────────────────────────────────

@test "--orchestrator: exits 0 (with or without child .devline dirs)" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT' --orchestrator"
  [ "$status" -eq 0 ]
}

# ─── --headless ───────────────────────────────────────────────────────────────

@test "--headless: exits 0 without requiring user input" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_INIT' --headless"
  [ "$status" -eq 0 ]
}

# ─── error paths ──────────────────────────────────────────────────────────────

@test "dl-init exits 1 when not in git repo" {
  tmpdir=$(mktemp -d)
  run bash -c "cd '$tmpdir' && DEVLINE_MCP_MOCK=1 '$DF_INIT'"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not a git repo" ]] || [[ "$output" =~ "not inside a git" ]]
}

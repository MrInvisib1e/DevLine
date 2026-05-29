#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────
#
# dl-explain v4 tests — thin MCP wrapper
#
# In v4, dl-explain delegates to codebase-memory-mcp CLI.
# Tests use DEVLINE_MCP_MOCK=1 to stub MCP responses.
#
# The mock returns predictable JSON/text so we can test argument routing
# and output formatting without a real MCP server running.

setup() {
  export REPO
  REPO="$(mktemp -d)"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "initial" --quiet)
  mkdir -p "$REPO/.devline"
  # Write a minimal config.json so dl-explain knows the project name
  cat > "$REPO/.devline/config.json" <<'EOF'
{
  "service": "sample-repo",
  "mode": "project",
  "stack": { "runtime": "dotnet", "frontend": "sveltekit" },
  "last_synced": "abc123",
  "review_checks": ["naming","test-coverage","dead-code"],
  "quality_hooks": {},
  "auto_skills": []
}
EOF
  export DF_EXPLAIN="$BATS_TEST_DIRNAME/../bin/dl-explain"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  export DEVLINE_MCP_MOCK=1
}

teardown() {
  rm -rf "$REPO"
  unset DEVLINE_MCP_MOCK
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "dl-explain --version prints Devline version and exits 0" {
  run "$DF_EXPLAIN" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ Devline ]]
}

# ─── basic search (default mode) ───────────────────────────────────────────────

@test "dl-explain <query> exits 0 with mock" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' CommentService"
  [ "$status" -eq 0 ]
}

@test "dl-explain <query> prints non-empty output" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' CommentService"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

@test "dl-explain <query> prints node names from results wrapper format" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' CommentService"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "MockNode" ]]
}

@test "dl-explain --rank prints node names from results wrapper format" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --rank"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "MockNode" ]]
}

# ─── --rank ───────────────────────────────────────────────────────────────────

@test "dl-explain --rank exits 0" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --rank"
  [ "$status" -eq 0 ]
}

@test "dl-explain --rank --budget 256 exits 0" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --rank --budget 256"
  [ "$status" -eq 0 ]
}

# ─── --impact ─────────────────────────────────────────────────────────────────

@test "dl-explain --impact exits 0" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --impact"
  [ "$status" -eq 0 ]
}

# ─── --dead-code ──────────────────────────────────────────────────────────────

@test "dl-explain --dead-code exits 0" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --dead-code"
  [ "$status" -eq 0 ]
}

# ─── --clones ─────────────────────────────────────────────────────────────────

@test "dl-explain --clones exits 0" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --clones"
  [ "$status" -eq 0 ]
}

# ─── --diff ───────────────────────────────────────────────────────────────────

@test "dl-explain --diff HEAD HEAD exits 0" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --diff HEAD HEAD"
  [ "$status" -eq 0 ]
}

# ─── --node ───────────────────────────────────────────────────────────────────

@test "dl-explain --node <path> exits 0" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --node src/routes/+page.svelte"
  [ "$status" -eq 0 ]
}

# ─── --project ────────────────────────────────────────────────────────────────

@test "dl-explain --project <name> --rank exits 0" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --project sample-repo --rank"
  [ "$status" -eq 0 ]
}

# ─── --headless ───────────────────────────────────────────────────────────────

@test "dl-explain --headless --rank exits 0" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --headless --rank"
  [ "$status" -eq 0 ]
}

# ─── CI / degraded mode ───────────────────────────────────────────────────────

@test "no .devline/: exits 0 silently (CI mode)" {
  tmpdir=$(mktemp -d)
  (cd "$tmpdir" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "init" --quiet)
  run bash -c "cd '$tmpdir' && unset DEVLINE_MCP_MOCK && '$DF_EXPLAIN' Comment"
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ─── error paths ──────────────────────────────────────────────────────────────

@test "not a git repo: exits 1 with message" {
  tmpdir=$(mktemp -d)
  run bash -c "cd '$tmpdir' && '$DF_EXPLAIN' Comment 2>&1"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not a git repo" ]] || [[ "$output" =~ "not inside a git" ]]
}

# ─── --node trace_path ────────────────────────────────────────────────────────

@test "dl-explain --node calls trace_path not trace_call_path" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --node bin/dl-explain"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Outbound" ]]
  [[ "$output" =~ "Inbound" ]]
}

# ─── --diff detect_changes ────────────────────────────────────────────────────

@test "dl-explain --diff returns affected symbols output" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --diff HEAD~1 HEAD"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Affected symbols" ]]
}

# ─── --snippet ────────────────────────────────────────────────────────────────

@test "dl-explain --snippet returns snippet from MCP" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' --snippet bin/dl-explain 86 95"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "mock snippet" ]]
}

# ─── zero results graceful handling ───────────────────────────────────────────

@test "dl-explain query with zero results does not crash" {
  run bash -c "cd '$REPO' && DEVLINE_MCP_MOCK=1 '$DF_EXPLAIN' completely_nonexistent_symbol_xyz"
  [ "$status" -eq 0 ]
}

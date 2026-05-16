#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────
#
# df-explain v4 tests — thin MCP wrapper
#
# In v4, df-explain delegates to codebase-memory-mcp CLI.
# Tests use DEVFLOW_MCP_MOCK=1 to stub MCP responses.
#
# The mock returns predictable JSON/text so we can test argument routing
# and output formatting without a real MCP server running.

setup() {
  export REPO
  REPO="$(mktemp -d)"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "initial" --quiet)
  mkdir -p "$REPO/.devflow"
  # Write a minimal config.json so df-explain knows the project name
  cat > "$REPO/.devflow/config.json" <<'EOF'
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
  export DF_EXPLAIN="$BATS_TEST_DIRNAME/../bin/df-explain"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
  export DEVFLOW_MCP_MOCK=1
}

teardown() {
  rm -rf "$REPO"
  unset DEVFLOW_MCP_MOCK
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "df-explain --version prints DevFlow version and exits 0" {
  run "$DF_EXPLAIN" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── basic search (default mode) ───────────────────────────────────────────────

@test "df-explain <query> exits 0 with mock" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' CommentService"
  [ "$status" -eq 0 ]
}

@test "df-explain <query> prints non-empty output" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' CommentService"
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

# ─── --rank ───────────────────────────────────────────────────────────────────

@test "df-explain --rank exits 0" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' --rank"
  [ "$status" -eq 0 ]
}

@test "df-explain --rank --budget 256 exits 0" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' --rank --budget 256"
  [ "$status" -eq 0 ]
}

# ─── --impact ─────────────────────────────────────────────────────────────────

@test "df-explain --impact exits 0" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' --impact"
  [ "$status" -eq 0 ]
}

# ─── --dead-code ──────────────────────────────────────────────────────────────

@test "df-explain --dead-code exits 0" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' --dead-code"
  [ "$status" -eq 0 ]
}

# ─── --clones ─────────────────────────────────────────────────────────────────

@test "df-explain --clones exits 0" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' --clones"
  [ "$status" -eq 0 ]
}

# ─── --diff ───────────────────────────────────────────────────────────────────

@test "df-explain --diff HEAD HEAD exits 0" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' --diff HEAD HEAD"
  [ "$status" -eq 0 ]
}

# ─── --node ───────────────────────────────────────────────────────────────────

@test "df-explain --node <path> exits 0" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' --node src/routes/+page.svelte"
  [ "$status" -eq 0 ]
}

# ─── --project ────────────────────────────────────────────────────────────────

@test "df-explain --project <name> --rank exits 0" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' --project sample-repo --rank"
  [ "$status" -eq 0 ]
}

# ─── --headless ───────────────────────────────────────────────────────────────

@test "df-explain --headless --rank exits 0" {
  run bash -c "cd '$REPO' && DEVFLOW_MCP_MOCK=1 '$DF_EXPLAIN' --headless --rank"
  [ "$status" -eq 0 ]
}

# ─── CI / degraded mode ───────────────────────────────────────────────────────

@test "no .devflow/: exits 0 silently (CI mode)" {
  tmpdir=$(mktemp -d)
  (cd "$tmpdir" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "init" --quiet)
  run bash -c "cd '$tmpdir' && '$DF_EXPLAIN' Comment"
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

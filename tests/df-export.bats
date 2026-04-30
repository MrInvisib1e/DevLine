#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────

setup() {
  export REPO
  REPO="$(mktemp -d)"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "initial" --quiet)
  mkdir -p "$REPO/.devflow/branches/main"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-memory.json" "$REPO/.devflow/branches/main/memory.json"
  echo "# memory.md render" > "$REPO/.devflow/branches/main/memory.md"
  ln -sfn "branches/main" "$REPO/.devflow/active"
  export DF_EXPORT="$BATS_TEST_DIRNAME/../bin/df-export"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$REPO"
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "df-export --version prints DevFlow version and exits 0" {
  run "$DF_EXPORT" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── default export (markdown) ─────────────────────────────────────────────────

@test "default export: prints markdown block to stdout" {
  run bash -c "cd '$REPO' && '$DF_EXPORT'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "DevFlow Memory" ]] || [[ "$output" =~ "Stack" ]] || [[ "$output" =~ "dotnet" ]]
}

@test "default export: output contains stack runtime" {
  run bash -c "cd '$REPO' && '$DF_EXPORT'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dotnet" ]]
}

@test "default export: output contains architecture section" {
  run bash -c "cd '$REPO' && '$DF_EXPORT'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Architecture" ]] || [[ "$output" =~ "architecture" ]]
}

@test "default export: output contains conventions section" {
  run bash -c "cd '$REPO' && '$DF_EXPORT'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Convention" ]] || [[ "$output" =~ "convention" ]]
}

# ─── --format json ─────────────────────────────────────────────────────────────

@test "--format json: outputs raw memory.json content" {
  run bash -c "cd '$REPO' && '$DF_EXPORT' --format json"
  [ "$status" -eq 0 ]
  echo "$output" | jq . > /dev/null
  run bash -c "cd '$REPO' && '$DF_EXPORT' --format json | jq -r '.stack.runtime'"
  [ "$output" = "dotnet-9" ]
}

# ─── --output ──────────────────────────────────────────────────────────────────

@test "--output: writes export to file" {
  outfile="$(mktemp)"
  run bash -c "cd '$REPO' && '$DF_EXPORT' --output '$outfile'"
  [ "$status" -eq 0 ]
  [ -s "$outfile" ]
  rm -f "$outfile"
}

# ─── --snapshot ────────────────────────────────────────────────────────────────

@test "--snapshot: creates snapshot directory with memory files" {
  run bash -c "cd '$REPO' && '$DF_EXPORT' --snapshot"
  [ "$status" -eq 0 ]
  # Should have created at least one snapshot directory
  snapshot_count=$(find "$REPO/.devflow/snapshots" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  [ "$snapshot_count" -ge 1 ]
}

@test "--snapshot: snapshot contains memory.json" {
  bash -c "cd '$REPO' && '$DF_EXPORT' --snapshot"
  snapshot_dir=$(find "$REPO/.devflow/snapshots" -mindepth 1 -maxdepth 1 -type d | head -1)
  [ -f "$snapshot_dir/memory.json" ]
}

# ─── --restore ─────────────────────────────────────────────────────────────────

@test "--restore: restores memory files from snapshot" {
  # Create snapshot first
  bash -c "cd '$REPO' && '$DF_EXPORT' --snapshot"
  snapshot_name=$(ls "$REPO/.devflow/snapshots/" | head -1)
  # Corrupt the live memory.json to prove restore overwrites it
  echo '{}' > "$REPO/.devflow/branches/main/memory.json"
  run bash -c "cd '$REPO' && '$DF_EXPORT' --restore '$snapshot_name'"
  [ "$status" -eq 0 ]
  # After restore, memory.json should have stack.runtime back
  run jq -r '.stack.runtime // empty' "$REPO/.devflow/branches/main/memory.json"
  [ "$output" = "dotnet-9" ]
}

@test "--restore: non-existent snapshot name exits 1 with message" {
  run bash -c "cd '$REPO' && '$DF_EXPORT' --restore 'nonexistent-snapshot' 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]] || [[ "$output" =~ "Snapshot" ]]
}

# ─── error paths ───────────────────────────────────────────────────────────────

@test "no .devflow/: CI mode — exits 0 silently" {
  tmpdir="$(mktemp -d)"
  (cd "$tmpdir" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "init" --quiet)
  run bash -c "cd '$tmpdir' && '$DF_EXPORT'"
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "missing memory.json: exits 1 with message" {
  rm "$REPO/.devflow/branches/main/memory.json"
  run bash -c "cd '$REPO' && '$DF_EXPORT' 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "memory" ]] || [[ "$output" =~ "not initialised" ]]
}

#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────

setup() {
  export REPO
  REPO="$(mktemp -d)"
  (cd "$REPO" && git init -b main && git config user.email "t@t.com" && git config user.name "T" && git commit --allow-empty -m "initial" --quiet)
  mkdir -p "$REPO/.devflow/branches/main"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-slices.json" "$REPO/.devflow/branches/main/slices.json"
  ln -sfn "branches/main" "$REPO/.devflow/active"
  export DF_TEST="$BATS_TEST_DIRNAME/../bin/df-test"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$REPO"
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "df-test --version prints DevFlow version and exits 0" {
  run "$DF_TEST" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── happy path ────────────────────────────────────────────────────────────────

@test "happy path PASS: runs test_cmd, prints PASS, exits 0" {
  # Slice 1 has test_cmd: "echo PASS_SLICE_1" which exits 0
  run bash -c "cd '$REPO' && '$DF_TEST' 1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PASS" ]]
}

@test "happy path FAIL: runs test_cmd, prints FAIL, exits non-zero" {
  # Slice 2 has test_cmd: "exit 1" which exits 1
  run bash -c "cd '$REPO' && '$DF_TEST' 2 2>&1 || true"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "FAIL" ]]
}

@test "exit code passthrough: FAIL exits with test command exit code" {
  run bash -c "cd '$REPO' && '$DF_TEST' 2; echo exit_was:\$?"
  [[ "$output" =~ "exit_was:1" ]]
}

@test "status written to slices.json: PASS sets status to done" {
  bash -c "cd '$REPO' && '$DF_TEST' 1" || true
  run bash -c "jq -r '.slices[] | select(.id==1) | .status' '$REPO/.devflow/branches/main/slices.json'"
  [ "$status" -eq 0 ]
  [ "$output" = "done" ]
}

@test "status written to slices.json: FAIL sets status to failed" {
  bash -c "cd '$REPO' && '$DF_TEST' 2" || true
  run bash -c "jq -r '.slices[] | select(.id==2) | .status' '$REPO/.devflow/branches/main/slices.json'"
  [ "$status" -eq 0 ]
  [ "$output" = "failed" ]
}

@test "--list: prints all slices with statuses" {
  run bash -c "cd '$REPO' && '$DF_TEST' --list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "comments" ]]
  [[ "$output" =~ "pending" ]]
  [[ "$output" =~ "failed" ]]
  [[ "$output" =~ "done" ]]
}

@test "DEVFLOW_TEST_CMD override: uses env var instead of slices.json test_cmd" {
  run bash -c "cd '$REPO' && DEVFLOW_TEST_CMD='echo OVERRIDDEN' '$DF_TEST' 1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "OVERRIDDEN" ]]
}

# ─── error paths ───────────────────────────────────────────────────────────────

@test "slice not found: exits 1 with message" {
  run bash -c "cd '$REPO' && '$DF_TEST' 999 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

@test "no test_cmd: exits 1 with message" {
  # Slice 3 has test_cmd: null
  run bash -c "cd '$REPO' && '$DF_TEST' 3 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "no test_cmd" ]] || [[ "$output" =~ "No test" ]]
}

@test "no slices.json and no DEVFLOW_TEST_CMD: exits 1 with message" {
  rm "$REPO/.devflow/branches/main/slices.json"
  run bash -c "cd '$REPO' && '$DF_TEST' 1 2>&1 || true"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "No slice plan" ]] || [[ "$output" =~ "slice plan" ]]
}

@test "not a git repo: exits 1 with message" {
  tmpdir="$(mktemp -d)"
  run bash -c "cd '$tmpdir' && '$DF_TEST' 1 2>&1 || true"
  rm -rf "$tmpdir"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not a git repo" ]]
}

#!/usr/bin/env bats

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

# placeholder — tests added in Task 2
@test "placeholder passes" {
  true
}

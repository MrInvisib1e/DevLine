#!/usr/bin/env bats

# ─── helpers ───────────────────────────────────────────────────────────────────

setup() {
  # Create a temp dir and copy the sample-repo fixture into it
  export REPO
  REPO="$(mktemp -d)"
  cp -r "$BATS_TEST_DIRNAME/fixtures/sample-repo/." "$REPO/"
  (cd "$REPO" && git init -b main && git add . && git commit -m "initial" --quiet)
  export FIXTURE_AI="$BATS_TEST_DIRNAME/fixtures/ai-responses/df-init-response.json"
  export DF_INIT="$BATS_TEST_DIRNAME/../bin/df-init"
  export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
}

teardown() {
  rm -rf "$REPO"
}

# ─── --version ─────────────────────────────────────────────────────────────────

@test "df-init --version prints DevFlow version and exits 0" {
  run "$DF_INIT" --version
  [ "$status" -eq 0 ]
  [[ "$output" =~ DevFlow ]]
}

# ─── --scan output ─────────────────────────────────────────────────────────────

@test "--scan outputs valid JSON" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq . > /dev/null
}

@test "--scan output has required top-level keys" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.schema_version' > /dev/null
  echo "$output" | jq -e '.branch' > /dev/null
  echo "$output" | jq -e '.branch_canonicalized' > /dev/null
  echo "$output" | jq -e '.classified' > /dev/null
  echo "$output" | jq -e '.unclassified' > /dev/null
  echo "$output" | jq -e '.stack_hints' > /dev/null
}

@test "--scan classifies Entities/Comment.cs as entity" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.classified[] | select(.file == "Entities/Comment.cs") | select(.type == "entity")' > /dev/null
}

@test "--scan classifies Services/CommentService.cs as service" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.classified[] | select(.file == "Services/CommentService.cs") | select(.type == "service")' > /dev/null
}

@test "--scan classifies Contracts/CommentCreatedEvent.cs as contract" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.classified[] | select(.file == "Contracts/CommentCreatedEvent.cs") | select(.type == "contract")' > /dev/null
}

@test "--scan classifies src/routes/+page.svelte as route" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.classified[] | select(.file == "src/routes/+page.svelte") | select(.type == "route")' > /dev/null
}

@test "--scan puts src/lib/utils/slug.ts in unclassified" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.unclassified[] | select(.file == "src/lib/utils/slug.ts")' > /dev/null
}

@test "--scan stack_hints detects dotnet and sveltekit" {
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.stack_hints.files_found | index("Program.cs")' > /dev/null
  echo "$output" | jq -e '.stack_hints.files_found | index("vite.config.ts")' > /dev/null
}

# ─── Branch canonicalization ───────────────────────────────────────────────────

@test "--scan canonicalizes branch names with slashes" {
  (cd "$REPO" && git checkout -b feature/comments --quiet)
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  branch_canon=$(echo "$output" | jq -r '.branch_canonicalized')
  [ "$branch_canon" = "feature__comments" ]
}

@test "--scan canonicalizes nested branch names" {
  (cd "$REPO" && git checkout -b fix/auth/token-expiry --quiet)
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
  branch_canon=$(echo "$output" | jq -r '.branch_canonicalized')
  [ "$branch_canon" = "fix__auth__token-expiry" ]
}

# ─── Fresh init ────────────────────────────────────────────────────────────────

_build_patch() {
  local repo="$1"
  local branch_canon
  branch_canon=$(cd "$repo" && "$DF_INIT" --scan | jq -r '.branch_canonicalized')
  local sha
  sha=$(cd "$repo" && git rev-parse HEAD)
  jq --arg branch "$branch_canon" --arg sha "$sha" '{
    config: {
      service: "sample-repo",
      workspace: null,
      stack: "dotnet-9",
      test_cmd: "dotnet test",
      last_synced: $sha,
      schema_version: 1,
      node_types: { custom: [] },
      edge_staleness_threshold: 30,
      edge_rel_types: { builtin: ["depends_on","uses","persisted_in","implements","emits","handles"], custom: [] },
      graph_limits: { max_nodes: 2000, max_edges: 10000, prune_min_age_commits: 90 },
      classifiers: {}
    },
    memory: {
      schema_version: 1,
      last_synced: $sha,
      stack: .call2.stack,
      architecture: .call2.architecture,
      conventions: .call2.conventions
    },
    nodes: {
      schema_version: 1,
      nodes: (.call1 | map(select(.type != "unclassified") | {
        id: (.type + ":" + (.file | gsub("/"; ".") | sub("\\.[^.]+$"; ""))),
        name: (.file | split("/") | last | sub("\\.[^.]+$"; "")),
        type: .type,
        file: .file,
        intent: .intent,
        confidence: .confidence,
        last_seen_sha: $sha
      }))
    },
    edges: { schema_version: 1, edges: [] }
  }' "$FIXTURE_AI"
}

@test "fresh init: all required files created" {
  local patch
  patch=$(_build_patch "$REPO")
  run bash -c "cd '$REPO' && echo \$'$patch' | '$DF_INIT' --write-memory"
  [ "$status" -eq 0 ]
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  [ -f "$REPO/.devflow/config.json" ]
  [ -f "$REPO/.devflow/branches/$branch/memory.json" ]
  [ -f "$REPO/.devflow/branches/$branch/nodes.json" ]
  [ -f "$REPO/.devflow/branches/$branch/edges.json" ]
  [ -f "$REPO/.devflow/branches/$branch/memory.md" ]
}

@test "fresh init: active symlink points to current branch" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  [ -L "$REPO/.devflow/active" ]
  local branch_canon
  branch_canon=$(cd "$REPO" && "$DF_INIT" --scan | jq -r '.branch_canonicalized')
  local target
  target=$(readlink "$REPO/.devflow/active")
  [[ "$target" == *"$branch_canon"* ]]
}

@test "fresh init: config.json dirty flag is cleared" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  run bash -c "jq -e '.dirty == false or .dirty == null' '$REPO/.devflow/config.json'"
  [ "$status" -eq 0 ]
}

@test "fresh init: all JSON files are valid JSON" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  jq . "$REPO/.devflow/config.json" > /dev/null
  jq . "$REPO/.devflow/branches/$branch/memory.json" > /dev/null
  jq . "$REPO/.devflow/branches/$branch/nodes.json" > /dev/null
  jq . "$REPO/.devflow/branches/$branch/edges.json" > /dev/null
}

@test "fresh init: git hooks installed and executable" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  [ -x "$REPO/.git/hooks/post-commit" ]
  [ -x "$REPO/.git/hooks/post-checkout" ]
  grep -q "df-sync" "$REPO/.git/hooks/post-commit"
  grep -q "df-sync" "$REPO/.git/hooks/post-checkout"
}

@test "fresh init: nodes.json has schema_version 1" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  run jq -e '.schema_version == 1' "$REPO/.devflow/branches/$branch/nodes.json"
  [ "$status" -eq 0 ]
}

# ─── Re-init (patch forward) ──────────────────────────────────────────────────

@test "re-init: manual-confidence node intent is preserved" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"

  # Manually set confidence on a node
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  local nodes_file="$REPO/.devflow/branches/$branch/nodes.json"
  local tmp
  tmp=$(mktemp)
  jq '(.nodes[] | select(.file == "Entities/Comment.cs")).confidence = "manual" |
      (.nodes[] | select(.file == "Entities/Comment.cs")).intent = "MANUAL INTENT DO NOT OVERWRITE"' \
    "$nodes_file" > "$tmp" && mv "$tmp" "$nodes_file"

  # Re-init with same patch
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"

  # Manual intent must survive
  run jq -r '.nodes[] | select(.file == "Entities/Comment.cs") | .intent' "$nodes_file"
  [ "$output" = "MANUAL INTENT DO NOT OVERWRITE" ]
}

@test "re-init: sha updated in config.json" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"

  # Make a new commit
  (cd "$REPO" && touch newfile.txt && git add newfile.txt && git commit -m "second commit" --quiet)

  # Rebuild patch with new sha
  local new_patch
  new_patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$new_patch' | '$DF_INIT' --write-memory"

  local new_sha
  new_sha=$(cd "$REPO" && git rev-parse HEAD)
  run jq -r '.last_synced' "$REPO/.devflow/config.json"
  [ "$output" = "$new_sha" ]
}

# ─── --reset ──────────────────────────────────────────────────────────────────

@test "--reset: snapshot created before wipe" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  run bash -c "cd '$REPO' && '$DF_INIT' --reset"
  [ "$status" -eq 0 ]
  # At least one snapshot directory should exist
  local count
  count=$(find "$REPO/.devflow/snapshots" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 1 ]
}

@test "--reset: current branch directory wiped" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  run bash -c "cd '$REPO' && '$DF_INIT' --reset"
  [ "$status" -eq 0 ]
  # Branch dir should NOT exist after --reset (until --write-memory re-creates it)
  [ ! -d "$REPO/.devflow/branches/$branch" ]
}

@test "--reset: other branches untouched" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"

  # Create a second branch and init it
  # Use core.hooksPath=/dev/null to avoid triggering the post-checkout hook
  # (df-sync is not in PATH in the test environment — this test is about --reset, not hooks)
  (cd "$REPO" && git -c core.hooksPath=/dev/null checkout -b other-branch --quiet)
  local patch2
  patch2=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch2' | '$DF_INIT' --write-memory"

  # Reset back on main
  (cd "$REPO" && git -c core.hooksPath=/dev/null checkout main --quiet)
  bash -c "cd '$REPO' && '$DF_INIT' --reset"

  # other-branch should still have its files
  [ -d "$REPO/.devflow/branches/other-branch" ]
}

# ─── Hook idempotency ─────────────────────────────────────────────────────────

@test "hook idempotency: running --write-memory twice does not duplicate df-sync calls" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"

  local count
  count=$(grep -c "^df-sync$" "$REPO/.git/hooks/post-commit")
  [ "$count" -eq 1 ]
}

@test "hook idempotency: existing non-DevFlow hook content is preserved" {
  # Write a pre-existing hook without DevFlow header
  mkdir -p "$REPO/.git/hooks"
  printf '#!/bin/bash\necho "existing hook"\n' > "$REPO/.git/hooks/post-commit"
  chmod +x "$REPO/.git/hooks/post-commit"

  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"

  # Original content must survive
  grep -q "existing hook" "$REPO/.git/hooks/post-commit"
  # DevFlow call must also be present
  grep -q "df-sync" "$REPO/.git/hooks/post-commit"
}

@test "hook idempotency: DevFlow-managed hook is replaced not appended" {
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"

  # Should only have one DevFlow managed header
  local count
  count=$(grep -c "DevFlow managed" "$REPO/.git/hooks/post-commit")
  [ "$count" -eq 1 ]
}

@test "hook idempotency: existing non-DevFlow hook content preserved after second --write-memory" {
  # Write a pre-existing hook without DevFlow header
  mkdir -p "$REPO/.git/hooks"
  printf '#!/bin/bash\necho "existing hook"\n' > "$REPO/.git/hooks/post-commit"
  chmod +x "$REPO/.git/hooks/post-commit"

  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"
  # Run twice — this is where the old code failed
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"

  # Original content must survive even after second run
  grep -q "existing hook" "$REPO/.git/hooks/post-commit"
  # DevFlow call must still be present
  grep -q "df-sync" "$REPO/.git/hooks/post-commit"
  # Only one DevFlow managed header
  local count
  count=$(grep -c "DevFlow managed" "$REPO/.git/hooks/post-commit")
  [ "$count" -eq 1 ]
}

# ─── Error paths ──────────────────────────────────────────────────────────────

@test "df-init exits 1 and prints error when not in git repo" {
  local tmpdir
  tmpdir=$(mktemp -d)
  run bash -c "cd '$tmpdir' && '$DF_INIT' --scan"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Not a git repo" ]]
  rm -rf "$tmpdir"
}

@test "--write-memory exits 1 on invalid JSON input" {
  run bash -c "cd '$REPO' && echo 'not-json' | '$DF_INIT' --write-memory"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid memory patch JSON" ]]
}

@test "--write-memory leaves dirty:true on write failure" {
  # First init to create config
  local patch
  patch=$(_build_patch "$REPO")
  bash -c "cd '$REPO' && printf '%s' '$patch' | '$DF_INIT' --write-memory"

  # Make nodes.json unwritable so write fails
  local branch
  branch=$(cd "$REPO" && git rev-parse --abbrev-ref HEAD)
  chmod 444 "$REPO/.devflow/branches/$branch/nodes.json"

  # Build a new patch for re-init
  local patch2
  patch2=$(_build_patch "$REPO")
  run bash -c "cd '$REPO' && printf '%s' '$patch2' | '$DF_INIT' --write-memory"
  # Should fail
  [ "$status" -ne 0 ]

  # dirty flag must survive (still true from failed write)
  run jq -e '.dirty == true' "$REPO/.devflow/config.json"
  [ "$status" -eq 0 ]

  chmod 644 "$REPO/.devflow/branches/$branch/nodes.json"
}

# ─── CI mode ──────────────────────────────────────────────────────────────────

@test "CI mode: df-init --scan works even without .devflow" {
  # df-init is special — it always runs (no CI skip guard)
  run bash -c "cd '$REPO' && '$DF_INIT' --scan"
  [ "$status" -eq 0 ]
}

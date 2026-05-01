# DevFlow User-Ready Bug Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix seven confirmed bugs that prevent DevFlow from working correctly out of the box: a schema mismatch in df-resolve, stale paths in skill docs, missing worktree subcommands in df-workspace, duplicate content in resume.md, a silent AI stub in df-sync, a wrong field name in init docs, and a broken `--list` command in df-test.

**Architecture:** Each fix is isolated — one file at a time. Tests are written or updated before implementation code to ensure every change is verified. All existing bats tests must continue to pass after each task.

**Tech Stack:** bash, jq, bats (bash automated testing system)

---

## File Map

| File | Change |
|------|--------|
| `tests/fixtures/sample-graph-conflicts.json` | Rewrite to new schema (`nodes`, `id`, plain string `branch_a`/`branch_b`) |
| `tests/df-resolve.bats` | Update field references to match new fixture schema |
| `bin/df-resolve` | Fix `.conflicts`→`.nodes`, `.node_id`→`.id`, `.branch_a.value`→`.branch_a` |
| `tests/df-workspace.bats` | Add `create` and `worktree-remove` tests |
| `bin/df-workspace` | Add `cmd_worktree_create` + `cmd_worktree_remove` functions and dispatch |
| `skills/feature/phases/phase-3-execution.md` | `df-workspace remove` → `df-workspace worktree-remove` |
| `skills/feature/SKILL.md` | Fix pre-flight paths, fix Abort Cleanup `df-workspace remove` reference |
| `skills/feature/phases/resume.md` | Remove 4 duplicated sections (quick mode, error table, guard rails, abort cleanup) |
| `tests/df-sync.bats` | Add AI warning test (no DEVFLOW_AI_MOCK) |
| `bin/df-sync` | Add AI stub warning before `_do_sync` |
| `skills/init/SKILL.md` | `last_seen_sha` → `last_seen` (2 occurrences) |
| `tests/df-test.bats` | Add per-slice `--list` test |
| `bin/df-test` | Update `cmd_list` to read per-slice JSON files first |

---

## Task 1: Fix the graph_conflicts.json fixture (schema alignment — Fix A, part 1)

**Files:**
- Modify: `tests/fixtures/sample-graph-conflicts.json`

The fixture currently uses the old schema (`conflicts`, `node_id`, nested `branch_a`/`branch_b` objects). The real schema written by `df-sync` uses `nodes`, `id`, and plain string `branch_a`/`branch_b`. This task rewrites the fixture to match reality.

- [ ] **Step 1: Confirm old fixture content**

Run:
```bash
cat tests/fixtures/sample-graph-conflicts.json
```
Expected: see `"conflicts"` key, `"node_id"` fields, `"branch_a": { "branch": "...", "value": "..." }` nested objects.

- [ ] **Step 2: Rewrite the fixture**

Replace the entire file with:
```json
{
  "generated_at": "2026-01-01T00:00:00Z",
  "nodes": [
    {
      "id": "entity:Entities.Comment",
      "conflict": "intent",
      "branch_a": "Soft-deletable content unit",
      "branch_b": "Append-only comment log"
    },
    {
      "id": "service:Services.CommentService",
      "conflict": "intent",
      "branch_a": "Owns all comment mutations",
      "branch_b": "Read-only comment query service"
    }
  ],
  "edges": []
}
```

- [ ] **Step 3: Commit**

```bash
git add tests/fixtures/sample-graph-conflicts.json
git commit -m "fix(test): update graph_conflicts fixture to real schema (nodes/id/plain strings)"
```

---

## Task 2: Update df-resolve.bats to match new fixture schema (Fix A, part 2)

**Files:**
- Modify: `tests/df-resolve.bats`

The tests reference old field names that matched the old fixture. Update every assertion that reads `.conflicts[]`, `.node_id`, or `.branch_a.value`.

> **Note:** We update the tests BEFORE fixing df-resolve. This way, after Task 3 the tests pass; if we see them failing before Task 3, that is expected and correct.

- [ ] **Step 1: Run the current tests to see what fails**

```bash
cd /path/to/Development-Flow && bats tests/df-resolve.bats 2>&1 | head -50
```
Expected: multiple failures because df-resolve reads old schema keys that no longer exist in the fixture.

- [ ] **Step 2: Update the test at line 70 — "accept: removes resolved conflict"**

The test currently reads `.conflicts[]` and `.node_id`. Change it to `.nodes[]` and `.id`:

Old (line 70):
```bash
  run jq '[.conflicts[] | select(.node_id=="entity:Entities.Comment")] | length' "$REPO/.devflow/branches/main/graph_conflicts.json"
```

New:
```bash
  run jq '[.nodes[] | select(.id=="entity:Entities.Comment")] | length' "$REPO/.devflow/branches/main/graph_conflicts.json"
```

- [ ] **Step 3: Commit**

```bash
git add tests/df-resolve.bats
git commit -m "fix(test): update df-resolve.bats assertions to new graph_conflicts schema"
```

---

## Task 3: Fix df-resolve to read the new schema (Fix A, part 3)

**Files:**
- Modify: `bin/df-resolve`

There are three jq schema bugs in df-resolve. Fix all three.

**Bug 1 — `cmd_list` (lines 59–70):** reads `.conflicts | length` and `.conflicts[] | .node_id / .branch_a.branch / .branch_a.value`

**Bug 2 — `cmd_accept` (lines 97, 114, 116, 128–133):** reads `.conflicts[] | select(.node_id == $id)` and `.branch_a.value` / `.branch_b.value`, and `del(.conflicts[])` and `.conflicts | length`

- [ ] **Step 1: Fix `cmd_list`**

Replace lines 59–70:

Old:
```bash
  local count
  count=$(jq '.conflicts | length' "$conflicts_file")

  if [[ "$count" -eq 0 ]]; then
    echo "[DevFlow] No conflicts to resolve."
    exit 0
  fi

  echo "[DevFlow] ${count} unresolved conflict(s):"
  jq -r '.conflicts[] |
    "  \(.node_id)  [\(.field)]\n    A: \(.branch_a.branch) — \(.branch_a.value)\n    B: \(.branch_b.branch) — \(.branch_b.value)"
  ' "$conflicts_file"
```

New:
```bash
  local count
  count=$(jq '.nodes | length' "$conflicts_file")

  if [[ "$count" -eq 0 ]]; then
    echo "[DevFlow] No conflicts to resolve."
    exit 0
  fi

  echo "[DevFlow] ${count} unresolved conflict(s):"
  jq -r '.nodes[] |
    "  \(.id)  [\(.conflict)]\n    A: \(.branch_a)\n    B: \(.branch_b)"
  ' "$conflicts_file"
```

- [ ] **Step 2: Fix `cmd_accept` — conflict existence check (line 97)**

Old:
```bash
  conflict_count=$(jq --arg id "$node_id" '[.conflicts[] | select(.node_id == $id)] | length' "$conflicts_file")
```

New:
```bash
  conflict_count=$(jq --arg id "$node_id" '[.nodes[] | select(.id == $id)] | length' "$conflicts_file")
```

- [ ] **Step 3: Fix `cmd_accept` — get winning value (lines 113–116)**

Old:
```bash
  if [[ "$choice" == "a" ]]; then
    winning_value=$(jq -r --arg id "$node_id" '.conflicts[] | select(.node_id == $id) | .branch_a.value' "$conflicts_file")
  else
    winning_value=$(jq -r --arg id "$node_id" '.conflicts[] | select(.node_id == $id) | .branch_b.value' "$conflicts_file")
  fi
```

New:
```bash
  if [[ "$choice" == "a" ]]; then
    winning_value=$(jq -r --arg id "$node_id" '.nodes[] | select(.id == $id) | .branch_a' "$conflicts_file")
  else
    winning_value=$(jq -r --arg id "$node_id" '.nodes[] | select(.id == $id) | .branch_b' "$conflicts_file")
  fi
```

- [ ] **Step 4: Fix `cmd_accept` — delete resolved conflict and count remaining (lines 127–133)**

Old:
```bash
  local updated_conflicts
  updated_conflicts=$(jq --arg id "$node_id" \
    'del(.conflicts[] | select(.node_id == $id))' \
    "$conflicts_file")

  local remaining
  remaining=$(echo "$updated_conflicts" | jq '.conflicts | length')
```

New:
```bash
  local updated_conflicts
  updated_conflicts=$(jq --arg id "$node_id" \
    'del(.nodes[] | select(.id == $id))' \
    "$conflicts_file")

  local remaining
  remaining=$(echo "$updated_conflicts" | jq '.nodes | length')
```

- [ ] **Step 5: Run all df-resolve tests**

```bash
bats tests/df-resolve.bats
```
Expected: all tests PASS (17/17 or however many exist).

- [ ] **Step 6: Commit**

```bash
git add bin/df-resolve
git commit -m "fix(df-resolve): align schema to df-sync output (nodes/id/plain branch strings)"
```

---

## Task 4: Add worktree subcommands to df-workspace (Fix C — implementation)

**Files:**
- Modify: `bin/df-workspace`

Add two new functions: `cmd_worktree_create` and `cmd_worktree_remove`. These manage git worktrees in `.devflow/worktrees/`. **Important:** branch names may contain `/` (e.g., `feature/auth-slice-1`), so `mkdir -p "$(dirname "$worktree_path")"` is required before `git worktree add`.

- [ ] **Step 1: Add a git check helper**

After `check_prereqs()` (around line 18), add a new helper function:

```bash
check_git() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not a git repo."
    exit 1
  fi
}
```

- [ ] **Step 2: Add `cmd_worktree_create`**

After `cmd_read()` and before the `# ─── dispatch ───` block (around line 137), add:

```bash
cmd_worktree_create() {
  local branch="$1"
  check_git

  local root
  root="$(git rev-parse --show-toplevel)"
  local worktree_path="${root}/.devflow/worktrees/${branch}"

  if [[ -d "$worktree_path" ]]; then
    err "Worktree for branch \"${branch}\" already exists at: ${worktree_path}"
    exit 1
  fi

  mkdir -p "$(dirname "$worktree_path")"
  git worktree add "$worktree_path" -b "$branch"
  echo "[DevFlow] Worktree created at: ${worktree_path}"
}

cmd_worktree_remove() {
  local branch="$1"
  check_git

  local root
  root="$(git rev-parse --show-toplevel)"
  local worktree_path="${root}/.devflow/worktrees/${branch}"

  if [[ ! -d "$worktree_path" ]]; then
    err "Worktree for branch \"${branch}\" not found at: ${worktree_path}"
    exit 1
  fi

  git worktree remove "$worktree_path" --force
  git branch -D "$branch" || true
  echo "[DevFlow] Worktree removed: ${worktree_path}"
}
```

- [ ] **Step 3: Add dispatch cases**

In the `case "${1:-}"` block at the end of the file, add before the `''` case:

```bash
  create)
    if [[ $# -lt 2 ]]; then
      err "Usage: df-workspace create <branch>"
      exit 1
    fi
    cmd_worktree_create "$2"
    ;;
  worktree-remove)
    if [[ $# -lt 2 ]]; then
      err "Usage: df-workspace worktree-remove <branch>"
      exit 1
    fi
    cmd_worktree_remove "$2"
    ;;
```

Also update the empty-arg usage message from:
```bash
    err "Usage: df-workspace <add|remove|list|read> [args] | --version"
```
to:
```bash
    err "Usage: df-workspace <add|remove|list|read|create|worktree-remove> [args] | --version"
```

And update the unknown-subcommand fallback to catch `*)` (it already does, no change needed).

- [ ] **Step 4: Commit**

```bash
git add bin/df-workspace
git commit -m "feat(df-workspace): add create and worktree-remove subcommands for git worktrees"
```

---

## Task 5: Add df-workspace tests for the new subcommands (Fix C — tests)

**Files:**
- Modify: `tests/df-workspace.bats`

The test setup already creates a real git repo in `$REPO`, so `git worktree` will work.

- [ ] **Step 1: Add `create` tests at end of file**

```bash
# ─── create (worktree) ────────────────────────────────────────────────────────

@test "create: creates a git worktree at .devflow/worktrees/<branch>" {
  run bash -c "cd '$REPO' && '$DF_WORKSPACE' create feature/test-slice-1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Worktree created" ]]
  [ -d "$REPO/.devflow/worktrees/feature/test-slice-1" ]
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
  [ ! -d "$REPO/.devflow/worktrees/feature/test-slice-1" ]
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
```

- [ ] **Step 2: Run all df-workspace tests**

```bash
bats tests/df-workspace.bats
```
Expected: all tests PASS.

- [ ] **Step 3: Commit**

```bash
git add tests/df-workspace.bats
git commit -m "test(df-workspace): add tests for create and worktree-remove subcommands"
```

---

## Task 6: Update skill docs for worktree subcommand rename (Fix C — docs)

**Files:**
- Modify: `skills/feature/phases/phase-3-execution.md` (line 143)
- Modify: `skills/feature/SKILL.md` (line 192)

Two places in skill markdown still reference `df-workspace remove` when they mean the worktree teardown, not the registry remove.

- [ ] **Step 1: Fix phase-3-execution.md**

On line 143, change:
```
   df-workspace remove feature/<feature-slug>-slice-N
```
To:
```
   df-workspace worktree-remove feature/<feature-slug>-slice-N
```

- [ ] **Step 2: Fix SKILL.md Abort Cleanup Protocol**

On line 192, change:
```
3. Clean up worktrees (`df-workspace remove` for each active worktree)
```
To:
```
3. Clean up worktrees (`df-workspace worktree-remove` for each active worktree)
```

- [ ] **Step 3: Commit**

```bash
git add skills/feature/phases/phase-3-execution.md skills/feature/SKILL.md
git commit -m "fix(skills): update df-workspace remove → worktree-remove in teardown docs"
```

---

## Task 7: Fix stale pre-flight paths in feature/SKILL.md (Fix B)

**Files:**
- Modify: `skills/feature/SKILL.md` (lines 42–50)

The pre-flight checks reference `.devflow/memory/` which doesn't exist. The real layout uses `.devflow/active/` (a symlink to `.devflow/branches/<branch>/`).

- [ ] **Step 1: Update Check 1 (line 43)**

Old:
```bash
which df-init && ls .devflow/memory/ 2>/dev/null
```
New:
```bash
which df-init && test -d .devflow/
```

- [ ] **Step 2: Update the halt condition for Check 2 (line 50)**

Old:
```
If `.devflow/memory/` is empty or missing: HALT — "Memory is empty. Run `/init` to set up project memory."
```
New:
```
If `.devflow/active` symlink is missing or the active directory is empty: HALT — "Memory is empty. Run `/init` to set up project memory."
```

Also change the example command in Check 2. The section currently says `ls .devflow/memory/`; add a new bash block below the halt condition:

```bash
test -L .devflow/active && ls .devflow/active/
```

- [ ] **Step 3: Commit**

```bash
git add skills/feature/SKILL.md
git commit -m "fix(skills): update stale pre-flight .devflow/memory/ paths to .devflow/active/"
```

---

## Task 8: Remove duplicate content from resume.md (Fix D)

**Files:**
- Modify: `skills/feature/phases/resume.md`

Lines 60–117 contain four sections that are exact duplicates of content in `skills/feature/SKILL.md`: Quick Mode table, Error Reference (E01–E15), Guard Rails, and Abort Cleanup Protocol. Remove all four and replace with a single reference line.

- [ ] **Step 1: Verify line numbers before editing**

```bash
grep -n "## Quick Mode\|## Error Reference\|### Guard Rails\|### Abort Cleanup" skills/feature/phases/resume.md
```
Expected output (approximately):
```
60:## Quick Mode
78:## Error Reference
98:### Guard Rails
110:### Abort Cleanup Protocol
```

- [ ] **Step 2: Remove lines 59–117 (the duplicated sections)**

Replace the block starting from `---` before `## Quick Mode` through the end of the file with a single reference note:

The new end of the file (after line 58 `---`) should be:

```markdown
> For quick mode reference, error codes (E01–E15), guard rails, and abort cleanup protocol, see `skills/feature/SKILL.md`.
```

So the file ends at what is currently line 58 (`---`) followed by the new reference line. The full replacement: delete lines 59–117, then append the reference note.

- [ ] **Step 3: Confirm the file ends correctly**

```bash
tail -5 skills/feature/phases/resume.md
```
Expected:
```
---

> For quick mode reference, error codes (E01–E15), guard rails, and abort cleanup protocol, see `skills/feature/SKILL.md`.
```

- [ ] **Step 4: Commit**

```bash
git add skills/feature/phases/resume.md
git commit -m "fix(skills): remove duplicate quick-mode/error/guard-rails/abort sections from resume.md"
```

---

## Task 9: Add AI stub warning to df-sync (Fix E — implementation)

**Files:**
- Modify: `bin/df-sync` (between lines 698 and 699)

Add a warning before `_do_sync` is called in `cmd_sync`. This warning fires only when `DEVFLOW_AI_MOCK` is not set to `1`.

- [ ] **Step 1: Locate the exact insertion point**

```bash
grep -n "acquire_lock\|_do_sync" bin/df-sync
```
Expected output shows `acquire_lock` at ~698 and `_do_sync` at ~699.

- [ ] **Step 2: Insert the warning**

Between `acquire_lock` and `_do_sync "$force" "$all_flag"`, add:

```bash
  if [[ "${DEVFLOW_AI_MOCK:-}" != "1" ]]; then
    err "Note: AI enrichment is not configured. Graph nodes will have no intent annotations."
    err "Set DEVFLOW_AI_MOCK=1 with DEVFLOW_AI_MOCK_FILE=<path> for testing."
  fi
```

The updated block in `cmd_sync` becomes:

```bash
  acquire_lock
  if [[ "${DEVFLOW_AI_MOCK:-}" != "1" ]]; then
    err "Note: AI enrichment is not configured. Graph nodes will have no intent annotations."
    err "Set DEVFLOW_AI_MOCK=1 with DEVFLOW_AI_MOCK_FILE=<path> for testing."
  fi
  _do_sync "$force" "$all_flag"
```

- [ ] **Step 3: Commit**

```bash
git add bin/df-sync
git commit -m "fix(df-sync): warn when AI enrichment is not configured"
```

---

## Task 10: Add df-sync AI warning test (Fix E — tests)

**Files:**
- Modify: `tests/df-sync.bats`

The existing df-sync.bats setup always exports `DEVFLOW_AI_MOCK=1`. The new test must explicitly unset it to trigger the warning.

- [ ] **Step 1: Find a good place to add the test in df-sync.bats**

```bash
grep -n "^@test" tests/df-sync.bats | tail -5
```
Note the last test name/line number. Add the new test at the end of the file.

- [ ] **Step 2: Add the AI warning test**

Append to `tests/df-sync.bats`:

```bash
# ─── AI warning ──────────────────────────────────────────────────────────────

@test "df-sync: prints AI enrichment warning when DEVFLOW_AI_MOCK is not set" {
  _init_repo "$REPO"
  run bash -c "cd '$REPO' && unset DEVFLOW_AI_MOCK && '$DF_SYNC' 2>&1"
  [[ "$output" =~ "AI enrichment is not configured" ]]
}
```

Note: we capture both stdout and stderr with `2>&1` because `err()` writes to `>&2`.

- [ ] **Step 3: Run the test**

```bash
bats tests/df-sync.bats
```
Expected: all tests PASS including the new AI warning test.

- [ ] **Step 4: Commit**

```bash
git add tests/df-sync.bats
git commit -m "test(df-sync): assert AI enrichment warning fires when DEVFLOW_AI_MOCK unset"
```

---

## Task 11: Fix `last_seen_sha` → `last_seen` in init/SKILL.md (Fix F)

**Files:**
- Modify: `skills/init/SKILL.md` (lines 220 and 233)

Two occurrences of `last_seen_sha` in the JSON schema examples must be renamed to `last_seen` to match what `df-sync` actually writes.

- [ ] **Step 1: Confirm both occurrences**

```bash
grep -n "last_seen_sha" skills/init/SKILL.md
```
Expected: exactly 2 lines (220 and 233).

- [ ] **Step 2: Replace both occurrences**

Line 220 — change:
```
        "last_seen_sha": "<head_sha>"
```
to:
```
        "last_seen": "<head_sha>"
```

Line 233 — change:
```
        "last_seen_sha": "<head_sha>"
```
to:
```
        "last_seen": "<head_sha>"
```

- [ ] **Step 3: Verify no occurrences remain**

```bash
grep -c "last_seen_sha" skills/init/SKILL.md
```
Expected: `0`

- [ ] **Step 4: Commit**

```bash
git add skills/init/SKILL.md
git commit -m "fix(skills): rename last_seen_sha to last_seen in init SKILL.md schema examples"
```

---

## Task 12: Fix df-test `--list` to support per-slice JSON format (Fix G — implementation)

**Files:**
- Modify: `bin/df-test` (function `cmd_list`, lines 68–93)

The current `cmd_list` only reads the legacy `slices.json`. It must check for per-slice `slice-*.json` files first (the same detection logic used in `cmd_run`).

- [ ] **Step 1: Read the full `cmd_list` function to confirm current code**

```bash
sed -n '68,93p' bin/df-test
```
Expected: the current function reads `${devflow_dir}/active/slices.json` only.

- [ ] **Step 2: Replace `cmd_list` with the new implementation**

Replace lines 68–93 entirely:

```bash
cmd_list() {
  check_prereqs

  local devflow_dir
  devflow_dir="$(git rev-parse --show-toplevel)/.devflow"
  local active_dir="${devflow_dir}/active"

  # ── Per-slice JSON mode ───────────────────────────────────────────────────
  if [[ -d "$active_dir" ]] || [[ -L "$active_dir" ]]; then
    local slice_files=()
    local f
    for f in "$active_dir"/*slice-*.json; do
      [[ -f "$f" ]] && slice_files+=("$f")
    done

    if [[ "${#slice_files[@]}" -gt 0 ]]; then
      local plan_name
      plan_name=$(basename "$(readlink "$active_dir" 2>/dev/null || echo "$active_dir")")
      echo "[DevFlow] Active plan: ${plan_name}"
      for f in "${slice_files[@]}"; do
        local basename name status test_result
        basename=$(basename "$f" .json)
        name=$(jq -r '.name // "unknown"' "$f")
        status=$(jq -r '.status // "pending"' "$f")
        test_result=$(jq -r '.test_result // "—"' "$f")
        printf '  %-40s  %-20s  %-10s  %s\n' "$basename" "$name" "$status" "$test_result"
      done
      exit 0
    fi
  fi

  # ── Legacy slices.json mode ──────────────────────────────────────────────
  local slices_file="${active_dir}/slices.json"

  if [[ ! -f "$slices_file" ]]; then
    err "No slice plan found. Run the feature skill to create one."
    exit 1
  fi

  local feature approved_at
  feature=$(jq -r '.feature' "$slices_file")
  approved_at=$(jq -r '.approved_at' "$slices_file")

  echo "Slice plan: $feature (approved $approved_at)"

  while IFS= read -r slice; do
    local id name status
    id=$(printf '%s' "$slice" | jq -r '.id')
    name=$(printf '%s' "$slice" | jq -r '.name')
    status=$(printf '%s' "$slice" | jq -r '.status')
    printf '  [%-11s] %d  %s\n' "$status" "$id" "$name"
  done < <(jq -c '.slices[]' "$slices_file")
}
```

- [ ] **Step 3: Commit**

```bash
git add bin/df-test
git commit -m "fix(df-test): update --list to read per-slice JSON format first, fall back to legacy"
```

---

## Task 13: Add df-test `--list` per-slice test (Fix G — tests)

**Files:**
- Modify: `tests/df-test.bats`

Add a test that sets up per-slice JSON files and verifies `df-test --list` reads them.

- [ ] **Step 1: Read the existing test setup to understand the REPO layout**

```bash
head -30 tests/df-test.bats
```
Note the `setup()` pattern — it creates `$REPO` as a temp git dir and exports `$DF_TEST`.

- [ ] **Step 2: Find where the `--list` tests live in the file**

```bash
grep -n "cmd_list\|--list\|df-test --list" tests/df-test.bats
```

- [ ] **Step 3: Add the per-slice `--list` test**

Find the section for `--list` tests and append (or create the section if absent):

```bash
@test "--list: shows per-slice JSON files when they exist" {
  # Setup: create .devflow/active/ (real dir, not symlink) with two slice JSON files
  mkdir -p "$REPO/.devflow/active"
  printf '%s\n' '{"id":"slice-1-auth","name":"auth setup","status":"pending","test_result":null}' \
    > "$REPO/.devflow/active/slice-1-auth.json"
  printf '%s\n' '{"id":"slice-2-api","name":"api layer","status":"done","test_result":"PASS"}' \
    > "$REPO/.devflow/active/slice-2-api.json"

  run bash -c "cd '$REPO' && '$DF_TEST' --list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "slice-1-auth" ]]
  [[ "$output" =~ "auth setup" ]]
  [[ "$output" =~ "slice-2-api" ]]
  [[ "$output" =~ "api layer" ]]
}
```

- [ ] **Step 4: Run the df-test tests**

```bash
bats tests/df-test.bats
```
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/df-test.bats
git commit -m "test(df-test): add --list per-slice JSON detection test"
```

---

## Task 14: Final verification — run full test suite

**Files:** (none modified)

Run the entire bats suite to confirm nothing regressed.

- [ ] **Step 1: Run all tests**

```bash
bats tests/
```
Expected: all test files pass. Note any failures and investigate before claiming done.

- [ ] **Step 2: Confirm git log looks clean**

```bash
git log --oneline -15
```
Expected: 13 commits, one per task from this plan.

- [ ] **Step 3: Done**

All 7 fixes are implemented and verified. The library is user-ready.

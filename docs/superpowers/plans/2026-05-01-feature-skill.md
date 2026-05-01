# Feature Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `skills/feature/SKILL.md` (orchestration) + 5 agent prompt files + update `bin/df-test` to read per-slice JSON files from `.devflow/plans/`.

**Architecture:** Orchestrator skill (SKILL.md) drives 6 phases via LLM-readable step-by-step instructions; 5 focused agent prompt templates define each subagent's role and output contract; `df-test` updated with backward-compatible per-slice JSON reading (falls back to legacy `slices.json`). All new fixture files added; 3 new bats test cases added to `df-test.bats`.

**Tech Stack:** Bash (df-test), Markdown (skill files), bats (tests), jq (JSON parsing).

---

## File Map

### New files (skills)
- `skills/feature/SKILL.md` — main session orchestrator (~700 lines)
- `skills/feature/agents/implementation.md` — Implementation Agent prompt template
- `skills/feature/agents/test.md` — Test Agent prompt template
- `skills/feature/agents/slice-review.md` — Slice Review Agent prompt template
- `skills/feature/agents/integration-test.md` — Integration Test Agent prompt template
- `skills/feature/agents/final-review.md` — Final Review Agent prompt template

### Modified files (scripts + tests)
- `bin/df-test` — update `cmd_list` and `cmd_run` to read per-slice JSON from `.devflow/plans/`
- `tests/df-test.bats` — add 3 new test cases for per-slice JSON reading
- `tests/fixtures/sample-slice-1-create-comment.json` — new fixture (per-slice JSON format)
- `tests/fixtures/sample-slice-2-delete-comment.json` — new fixture
- `tests/fixtures/sample-plan.md` — minimal plan.md fixture for df-test tests

---

## Task 1: Create fixture files for per-slice JSON format

These fixtures are needed before we can write or run any df-test tests for the new format.

**Files:**
- Create: `tests/fixtures/sample-slice-1-create-comment.json`
- Create: `tests/fixtures/sample-slice-2-delete-comment.json`
- Create: `tests/fixtures/sample-plan.md`

- [ ] **Step 1: Create slice-1 fixture**

```bash
cat > tests/fixtures/sample-slice-1-create-comment.json << 'EOF'
{
  "id": 1,
  "name": "User can create a comment",
  "instructions": "slice-1-create-comment.md",
  "layers": ["db", "service", "api", "frontend"],
  "result": "POST /api/comments returns 201, comment appears in UI",
  "test_cmd": "echo PASS_SLICE_1",
  "depends_on": [],
  "status": "pending",
  "cycle": 0,
  "max_cycles": 3,
  "steps": [
    { "id": "s1", "action": "create", "file": "Entities/Comment.cs", "done": false }
  ],
  "test_steps": [
    { "id": "t1", "file": "tests/comments.spec.ts", "done": false }
  ],
  "implementation_summary": null,
  "files_changed": null,
  "test_result": null,
  "test_summary": null,
  "test_agent_skipped": false,
  "test_agent_skip_reason": null,
  "review_findings": null,
  "concerns": null,
  "worktree_path": null
}
EOF
```

- [ ] **Step 2: Create slice-2 fixture**

```bash
cat > tests/fixtures/sample-slice-2-delete-comment.json << 'EOF'
{
  "id": 2,
  "name": "User can delete a comment",
  "instructions": "slice-2-delete-comment.md",
  "layers": ["service", "api", "frontend"],
  "result": "DELETE /api/comments/:id returns 204",
  "test_cmd": "exit 1",
  "depends_on": [1],
  "status": "failed",
  "cycle": 1,
  "max_cycles": 3,
  "steps": [
    { "id": "s1", "action": "modify", "file": "Services/CommentService.cs", "done": true }
  ],
  "test_steps": [
    { "id": "t1", "file": "tests/comments.spec.ts", "done": false }
  ],
  "implementation_summary": "Added delete method to CommentService",
  "files_changed": ["Services/CommentService.cs"],
  "test_result": "FAIL (0/1)",
  "test_summary": null,
  "test_agent_skipped": false,
  "test_agent_skip_reason": null,
  "review_findings": null,
  "concerns": null,
  "worktree_path": null
}
EOF
```

- [ ] **Step 3: Create sample plan.md fixture**

```bash
cat > tests/fixtures/sample-plan.md << 'EOF'
# Comments Feature

## PRD: Comments

**Actor:** authenticated user
**Goal:** create and delete comments on stories
**Scope:** comment CRUD
**Out of scope:** comment moderation
**Success criteria:** user can create and delete comments

## Execution Batches

Batch 1 (parallel): slice-1-create-comment, slice-2-delete-comment
EOF
```

- [ ] **Step 4: Verify fixtures are valid JSON**

```bash
jq . tests/fixtures/sample-slice-1-create-comment.json
jq . tests/fixtures/sample-slice-2-delete-comment.json
```

Expected: both print their JSON without errors.

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures/sample-slice-1-create-comment.json tests/fixtures/sample-slice-2-delete-comment.json tests/fixtures/sample-plan.md
git commit -m "test: add per-slice JSON fixtures for df-test"
```

---

## Task 2: Add new df-test tests (write failing tests first)

Add 3 new bats test cases. These will fail until `df-test` is updated in Task 3.

**Files:**
- Modify: `tests/df-test.bats`

- [ ] **Step 1: Add new test cases to df-test.bats**

Open `tests/df-test.bats` and add a new section after line 106 (end of existing tests):

```bash
# ─── per-slice JSON format (new plan folder layout) ────────────────────────────

setup_plan_dir() {
  local plans_dir="$REPO/.devflow/plans/2026-05-01-feature-comments"
  mkdir -p "$plans_dir"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-slice-1-create-comment.json" \
     "$plans_dir/slice-1-create-comment.json"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-slice-2-delete-comment.json" \
     "$plans_dir/slice-2-delete-comment.json"
  cp "$BATS_TEST_DIRNAME/fixtures/sample-plan.md" "$plans_dir/plan.md"
  rm -f "$REPO/.devflow/active"
  ln -sfn "plans/2026-05-01-feature-comments" "$REPO/.devflow/active"
}

@test "per-slice JSON: --list reads slice-*.json files from active plan folder" {
  setup_plan_dir
  run bash -c "cd '$REPO' && '$DF_TEST' --list"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "create a comment" ]]
  [[ "$output" =~ "delete a comment" ]]
}

@test "per-slice JSON: runs test_cmd from slice-N.json, exits 0 on PASS" {
  setup_plan_dir
  run bash -c "cd '$REPO' && '$DF_TEST' 1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "PASS" ]]
}

@test "per-slice JSON: slices sorted by id (slice-2 found after slice-1)" {
  setup_plan_dir
  run bash -c "cd '$REPO' && '$DF_TEST' 2 2>&1"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "FAIL" ]]
}
```

- [ ] **Step 2: Run tests to confirm they FAIL (expected before implementation)**

```bash
cd /Volumes/ReydoSSD/SourceCode/Development-Flow && bats tests/df-test.bats 2>&1 | tail -20
```

Expected: 3 new tests FAIL, all existing 10 tests still PASS.

- [ ] **Step 3: Commit failing tests**

```bash
git add tests/df-test.bats
git commit -m "test(df-test): add 3 failing tests for per-slice JSON plan folder layout"
```

---

## Task 3: Update df-test to support per-slice JSON from plan folder

Update `bin/df-test` to detect the new plan folder layout (per-slice JSON files) while maintaining full backward compatibility with the legacy `slices.json` format.

**Files:**
- Modify: `bin/df-test`

**Current behavior:** reads `.devflow/active/slices.json` (a single file with a `.slices[]` array).

**New behavior:**
1. Resolve `.devflow/active` symlink → get plan folder path
2. Check if `slice-*.json` files exist in that folder
3. If yes: read individual slice JSON files (new format)
4. If no: fall back to `slices.json` with deprecation warning (legacy format)

- [ ] **Step 1: Add helper functions for per-slice JSON reading**

After the `atomic_write` function (after line 30) in `bin/df-test`, add:

```bash
# Resolve .devflow/active → plan folder path
# Returns: absolute path to plan folder, or "" if .devflow/active doesn't exist
resolve_plan_dir() {
  local devflow_dir="$1"
  local active_link="${devflow_dir}/active"
  if [[ ! -e "$active_link" ]]; then
    echo ""
    return
  fi
  local target
  target=$(readlink "$active_link")
  if [[ "$target" = /* ]]; then
    echo "$target"
  else
    echo "${devflow_dir}/${target}"
  fi
}

# List all slice JSON files from plan folder, sorted by id
# Returns: paths to slice-*.json files sorted by .id field, one per line
list_slice_files() {
  local plan_dir="$1"
  # Collect all slice-*.json files, sort by their .id field
  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$plan_dir" -maxdepth 1 -name 'slice-*.json' -print0 2>/dev/null)

  if [[ ${#files[@]} -eq 0 ]]; then
    return
  fi

  # Sort by .id using jq
  printf '%s\n' "${files[@]}" | while IFS= read -r f; do
    id=$(jq -r '.id' "$f" 2>/dev/null || echo "9999")
    echo "${id} ${f}"
  done | sort -n | awk '{print $2}'
}

# Check if plan folder uses per-slice JSON format (has slice-*.json files)
has_per_slice_format() {
  local plan_dir="$1"
  local count
  count=$(find "$plan_dir" -maxdepth 1 -name 'slice-*.json' 2>/dev/null | wc -l | tr -d ' ')
  [[ "$count" -gt 0 ]]
}
```

- [ ] **Step 2: Update cmd_list to support both formats**

Replace the existing `cmd_list` function (lines 39–64) with:

```bash
cmd_list() {
  check_prereqs

  local devflow_dir
  devflow_dir="$(git rev-parse --show-toplevel)/.devflow"

  local plan_dir
  plan_dir=$(resolve_plan_dir "$devflow_dir")

  if [[ -n "$plan_dir" ]] && has_per_slice_format "$plan_dir"; then
    # New per-slice JSON format
    echo "Slice plan: $(basename "$plan_dir")"
    while IFS= read -r slice_file; do
      local id name status
      id=$(jq -r '.id' "$slice_file")
      name=$(jq -r '.name' "$slice_file")
      status=$(jq -r '.status' "$slice_file")
      printf '  [%-11s] %d  %s\n' "$status" "$id" "$name"
    done < <(list_slice_files "$plan_dir")
    return
  fi

  # Legacy slices.json format
  local slices_file="${devflow_dir}/active/slices.json"
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

- [ ] **Step 3: Update cmd_run to support both formats**

Replace the existing `cmd_run` function (lines 66–152) with:

```bash
cmd_run() {
  local slice_id="$1"

  check_prereqs

  local devflow_dir
  devflow_dir="$(git rev-parse --show-toplevel)/.devflow"

  # Check for DEVFLOW_TEST_CMD override first — can run even without any plan files
  if [[ -n "${DEVFLOW_TEST_CMD:-}" ]]; then
    echo "[DevFlow] Running slice ${slice_id} (DEVFLOW_TEST_CMD override)"
    set +e
    # shellcheck disable=SC2294
    ( eval "$DEVFLOW_TEST_CMD" )
    local exit_code=$?
    set -e
    if [[ "$exit_code" -eq 0 ]]; then
      echo "[DevFlow] PASS"
    else
      echo "[DevFlow] FAIL (exit ${exit_code})"
    fi
    # Try to update status in whichever format exists
    local plan_dir
    plan_dir=$(resolve_plan_dir "$devflow_dir")
    if [[ -n "$plan_dir" ]] && has_per_slice_format "$plan_dir"; then
      local slice_file
      slice_file=$(list_slice_files "$plan_dir" | while IFS= read -r f; do
        fid=$(jq -r '.id' "$f")
        [[ "$fid" == "$slice_id" ]] && echo "$f" && break
      done)
      if [[ -n "$slice_file" ]]; then
        local new_status="failed"
        [[ "$exit_code" -eq 0 ]] && new_status="done"
        local updated
        updated=$(jq --arg s "$new_status" '.status = $s' "$slice_file")
        atomic_write "$slice_file" "$updated"
      fi
    else
      local slices_file="${devflow_dir}/active/slices.json"
      if [[ -f "$slices_file" ]]; then
        local new_status="failed"
        [[ "$exit_code" -eq 0 ]] && new_status="done"
        local updated
        updated=$(jq --argjson id "$slice_id" --arg s "$new_status" \
          '.slices = [.slices[] | if .id == $id then .status = $s else . end]' \
          "$slices_file")
        atomic_write "$slices_file" "$updated"
      fi
    fi
    exit "$exit_code"
  fi

  local plan_dir
  plan_dir=$(resolve_plan_dir "$devflow_dir")

  if [[ -n "$plan_dir" ]] && has_per_slice_format "$plan_dir"; then
    # New per-slice JSON format
    local slice_file=""
    while IFS= read -r f; do
      fid=$(jq -r '.id' "$f")
      if [[ "$fid" == "$slice_id" ]]; then
        slice_file="$f"
        break
      fi
    done < <(list_slice_files "$plan_dir")

    if [[ -z "$slice_file" ]]; then
      err "Slice ${slice_id} not found in plan folder."
      exit 1
    fi

    local slice_name test_cmd
    slice_name=$(jq -r '.name' "$slice_file")
    test_cmd=$(jq -r '.test_cmd // empty' "$slice_file")

    if [[ -z "$test_cmd" ]]; then
      err "Slice ${slice_id} has no test_cmd defined."
      exit 1
    fi

    echo "[DevFlow] Running slice ${slice_id}: ${slice_name}"

    set +e
    # shellcheck disable=SC2294
    ( eval "$test_cmd" )
    local exit_code=$?
    set -e

    local new_status="failed"
    if [[ "$exit_code" -eq 0 ]]; then
      echo "[DevFlow] PASS"
      new_status="done"
    else
      echo "[DevFlow] FAIL (exit ${exit_code})"
    fi

    local updated
    updated=$(jq --arg s "$new_status" '.status = $s' "$slice_file")
    atomic_write "$slice_file" "$updated"

    exit "$exit_code"
  fi

  # Legacy slices.json format
  local slices_file="${devflow_dir}/active/slices.json"

  if [[ ! -f "$slices_file" ]]; then
    if [[ ! -d "$devflow_dir" ]]; then
      err "No test command found. Set DEVFLOW_TEST_CMD or run df-init."
    else
      err "No slice plan found. Run the feature skill to create one."
    fi
    exit 1
  fi

  # Find the slice
  local slice_json
  slice_json=$(jq -r --argjson id "$slice_id" '.slices[] | select(.id == $id)' "$slices_file")
  if [[ -z "$slice_json" ]]; then
    err "Slice ${slice_id} not found in slices.json."
    exit 1
  fi

  local slice_name test_cmd
  slice_name=$(printf '%s' "$slice_json" | jq -r '.name')
  test_cmd=$(printf '%s' "$slice_json" | jq -r '.test_cmd // empty')

  if [[ -z "$test_cmd" ]]; then
    err "Slice ${slice_id} has no test_cmd defined."
    exit 1
  fi

  echo "[DevFlow] Running slice ${slice_id}: ${slice_name}"

  set +e
  # shellcheck disable=SC2294
  ( eval "$test_cmd" )
  local exit_code=$?
  set -e

  local new_status="failed"
  if [[ "$exit_code" -eq 0 ]]; then
    echo "[DevFlow] PASS"
    new_status="done"
  else
    echo "[DevFlow] FAIL (exit ${exit_code})"
  fi

  # Write status back atomically
  local updated
  updated=$(jq --argjson id "$slice_id" --arg s "$new_status" \
    '.slices = [.slices[] | if .id == $id then .status = $s else . end]' \
    "$slices_file")
  atomic_write "$slices_file" "$updated"

  exit "$exit_code"
}
```

- [ ] **Step 4: Run ALL df-test tests — all 13 must pass**

```bash
cd /Volumes/ReydoSSD/SourceCode/Development-Flow && bats tests/df-test.bats
```

Expected: 13 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add bin/df-test
git commit -m "feat(df-test): support per-slice JSON plan folder layout

Reads slice-*.json files from .devflow/active plan folder (new format).
Falls back to slices.json for backward compatibility (legacy format).
Status updates written to individual slice JSON files in new format."
```

---

## Task 4: Write agents/implementation.md

**Files:**
- Create: `skills/feature/agents/implementation.md`

- [ ] **Step 1: Create the agents directory**

```bash
mkdir -p skills/feature/agents
```

- [ ] **Step 2: Write implementation.md**

```bash
cat > skills/feature/agents/implementation.md << 'AGENTEOF'
# Implementation Agent

**Role:** You are implementing one complete vertical slice of a feature across all affected application layers (database → service → API → frontend).

You have been dispatched by an orchestrator. You are a focused executor: read your mission briefing (the slice MD), implement what it describes, run the specified test, and report back.

---

## Inputs You Receive

The orchestrator provides:

1. **Slice Mission Briefing** — the slice-N-<slug>.md file content, pasted in full. This is your primary specification.
2. **Domain Analysis** — from plan.md § Domain Analysis and § Pattern Library. Follow these patterns exactly.
3. **Worktree path** (if parallel mode) or current branch (if sequential).
4. **Prior Work section** (only if this is a retry — cycle > 1). See below.

---

## What You Do

1. Read the slice mission briefing completely before writing any code.
2. Follow the Code Patterns in the briefing as your implementation template — adapt names, don't invent new patterns.
3. Implement every item in the **Files Touched** table.
4. Run the test command specified in **Expected Result**.
5. Commit your changes.
6. Report back in the required output format.

---

## Retry Mode (cycle > 1)

If you see a **## Prior Work** section at the top of your instructions:

- Read the existing files listed — do NOT re-implement from scratch.
- Fix ONLY the issues listed in **Required fixes**.
- Do not change anything not mentioned in the required fixes list.
- Re-run the test command after fixing.

---

## Output Format

Report back using EXACTLY this format:

```
Status: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED

What I Implemented:
[2-5 sentences describing what was built: entities, services, endpoints, components]

Tests:
[Test command you ran] → [result: PASS (N/N) or FAIL (N/N)]

Files Changed:
- path/to/file.ext — [one-line description of what changed]
- path/to/file.ext — [one-line description]

Self-Review:
[1-3 sentences: honest assessment — what's solid, what's approximate, any known gaps]

Issues / Concerns:
[Only if DONE_WITH_CONCERNS or BLOCKED. Be specific.]
```

**Status definitions:**
- `DONE` — implemented, tests pass, committed, nothing notable to flag
- `DONE_WITH_CONCERNS` — tests pass but there is a known limitation worth flagging
- `NEEDS_CONTEXT` — you cannot proceed without a specific piece of information (state exactly what you need)
- `BLOCKED` — you cannot proceed due to missing dependency, environment issue, or broken prerequisite (state exactly what is blocking you)

---

## Constraints

- **Do not** modify files outside the Files Touched table in your mission briefing.
- **Do not** refactor code unrelated to this slice.
- **Do not** skip writing or running the test.
- **Do not** invent patterns — follow the ones in the Pattern Library.
- **Always** commit before reporting back.
AGENTEOF
```

- [ ] **Step 3: Verify file exists and is readable**

```bash
wc -l skills/feature/agents/implementation.md
```

Expected: prints a line count (approximately 65 lines).

- [ ] **Step 4: Commit**

```bash
git add skills/feature/agents/implementation.md
git commit -m "feat(feature-skill): add Implementation Agent prompt template"
```

---

## Task 5: Write agents/test.md

**Files:**
- Create: `skills/feature/agents/test.md`

- [ ] **Step 1: Write test.md**

```bash
cat > skills/feature/agents/test.md << 'AGENTEOF'
# Test Agent

**Role:** You write new end-to-end and integration tests for a vertical slice that has already been implemented. You do not write implementation code.

You have been dispatched after the Implementation Agent completed its slice. Your job is to independently verify the slice's user-visible result by writing tests that an e2e test runner can execute.

---

## Inputs You Receive

The orchestrator provides:

1. **Slice Mission Briefing** — the slice-N-<slug>.md file content. Read the **Expected Result** section for what to test and the **test_cmd** for what command to run.
2. **Files Changed** — list of files the Implementation Agent created or modified.
3. **Test Patterns** — from plan.md § Pattern Library. Follow the test file conventions shown.

---

## What You Do

1. Read the slice mission briefing — specifically **Goal**, **Expected Result**, and **Files Touched**.
2. Write e2e or integration tests that verify the user-visible result.
3. Run the test command from the briefing's Expected Result section.
4. Report results in the required output format.

---

## What You Do NOT Do

- Write unit tests (mocked-dependency tests). E2e and integration only.
- Modify implementation files.
- Change the test_cmd — just run it.

---

## Output Format

```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED

Tests Written:
- path/to/test-file.spec.ts — [what user scenario this covers]
- path/to/test-file.spec.ts — [what user scenario this covers]

Test Results:
[test_cmd output summary: PASS (N/N) or FAIL (N/N) with relevant failure messages]

Coverage Notes:
[What happy paths and edge cases are covered. Any scenarios intentionally not tested and why.]

Concerns:
[Only if DONE_WITH_CONCERNS or BLOCKED. Be specific.]
```

**Status definitions:**
- `DONE` — tests written, test_cmd passes, coverage is adequate
- `DONE_WITH_CONCERNS` — tests pass but coverage has notable gaps (explain them)
- `BLOCKED` — cannot write or run tests (state exactly why)

---

## Constraints

- Write tests in the test files indicated by the slice's `test_steps` entries.
- Follow the test patterns from plan.md § Pattern Library.
- Run the complete test_cmd, not just your new tests.
- Never modify implementation files.
AGENTEOF
```

- [ ] **Step 2: Commit**

```bash
git add skills/feature/agents/test.md
git commit -m "feat(feature-skill): add Test Agent prompt template"
```

---

## Task 6: Write agents/slice-review.md

**Files:**
- Create: `skills/feature/agents/slice-review.md`

- [ ] **Step 1: Write slice-review.md**

```bash
cat > skills/feature/agents/slice-review.md << 'AGENTEOF'
# Slice Review Agent

**Role:** You review one vertical slice for specification compliance and code quality. You read code — you do not write it.

You have been dispatched after the Implementation Agent (and optionally the Test Agent) completed their work. Your job is to verify the implementation matches the spec and meets quality standards.

---

## Inputs You Receive

The orchestrator provides:

1. **Slice Mission Briefing** — the slice-N-<slug>.md file content. This is the specification you verify against.
2. **Implementation files** — the actual files created or modified (read them directly from disk using the paths in Files Changed).
3. **Test results** — the test_result string from the slice JSON (e.g., "PASS (3/3)" or "FAIL (1/3)").
4. **Domain Analysis** — from plan.md § Domain Analysis. Use this to understand what patterns are expected.

---

## What You Do

1. Read the slice mission briefing completely.
2. Read the actual implementation files.
3. Verify specification compliance: does the implementation do what the briefing says?
4. Assess code quality: is this code correct, safe, and maintainable?
5. Report a PASS or FAIL verdict with specific findings.

---

## Output Format

```
Verdict: PASS | FAIL

Spec Compliance:
- [✅|❌] Result matches slice MD Expected Result
- [✅|❌] All files in Files Touched table were created/modified
- [✅|❌] Tests exercise the user-visible result
- [✅|❌] [any slice-specific requirement from the briefing]

Code Quality:
CRITICAL: [correctness-blocking issues, data-loss risks, security vulnerabilities — be specific]
IMPORTANT: [issues that would cause problems under normal use — be specific]
MINOR: [style, naming, non-urgent improvements — be specific]

Test Adequacy:
[1-3 sentences on whether the tests adequately cover the user-visible result]

Required Changes:
[Specific, actionable list of what must be fixed before this slice is DONE.
 Empty if verdict is PASS.
 Each item must be a concrete instruction: "do X to Y in Z file"]
```

**Verdict rules:**
- `PASS` — spec compliant, no CRITICAL findings, fewer than 2 IMPORTANT findings
- `FAIL` — any CRITICAL finding, OR 2+ IMPORTANT findings, OR spec non-compliant

**Never write code.** If you find an issue, describe it precisely so the Implementation Agent can fix it.

---

## Constraints

- Review only the files in the Files Changed list for this slice.
- Do not comment on code outside the scope of this slice.
- Be specific: "the DeleteAsync method in CommentService.cs does not validate authorization" is a finding. "needs better error handling" is not.
AGENTEOF
```

- [ ] **Step 2: Commit**

```bash
git add skills/feature/agents/slice-review.md
git commit -m "feat(feature-skill): add Slice Review Agent prompt template"
```

---

## Task 7: Write agents/integration-test.md and agents/final-review.md

**Files:**
- Create: `skills/feature/agents/integration-test.md`
- Create: `skills/feature/agents/final-review.md`

- [ ] **Step 1: Write integration-test.md**

```bash
cat > skills/feature/agents/integration-test.md << 'AGENTEOF'
# Integration Test Agent

**Role:** You verify that multiple completed vertical slices work together correctly as a coherent feature. You write cross-slice tests — you do not modify implementation code.

You have been dispatched after all slices in all batches are complete. Your job is to test inter-slice behavior (things that only work when multiple slices are present) and to run the full test suite to catch regressions.

---

## Inputs You Receive

The orchestrator provides:

1. **All Slice Mission Briefings** — all slice-N-<slug>.md files, one per slice. Read them to understand what each slice delivers.
2. **plan.md** — for PRD (success criteria), Execution Batches, and batch structure.
3. **All changed files** — the union of files_changed across all slices.

---

## What You Do

1. Read all slice mission briefings to understand cross-slice interactions.
2. Identify scenarios that require multiple slices to be present (e.g., "user creates a comment, then deletes it").
3. Write tests that exercise these cross-slice scenarios.
4. Run the FULL test suite (not just your new tests).
5. Identify and report any regressions.

---

## Output Format

```
Status: DONE | DONE_WITH_CONCERNS | BLOCKED

Cross-Slice Interactions Verified:
- [scenario 1: e.g., "create then delete roundtrip"]
- [scenario 2: e.g., "list reflects created comments"]

Tests Written:
- path/to/integration.spec.ts — [what cross-slice behavior this covers]

Full Suite Results:
[Summary: PASS (N/N) or list of failures with test names and error messages]

Regressions:
[Any tests that PREVIOUSLY PASSED but now FAIL. List test names and failure reason.
 Write "None" if no regressions found.]

Issues:
[Only if DONE_WITH_CONCERNS or BLOCKED. Be specific.]
```

**Status definitions:**
- `DONE` — cross-slice tests written, full suite passes, no regressions
- `DONE_WITH_CONCERNS` — suite passes but there are notable coverage gaps or minor regressions in non-critical tests
- `BLOCKED` — cannot run tests (environment issue, missing dependency)

---

## Constraints

- Write only test files.
- Run the FULL test suite, not just your new tests.
- Never modify implementation files.
- Report regressions explicitly — do not silently skip failing tests.
AGENTEOF
```

- [ ] **Step 2: Write final-review.md**

```bash
cat > skills/feature/agents/final-review.md << 'AGENTEOF'
# Final Review Agent

**Role:** You perform an architecture-aware holistic review of the complete feature implementation. You read code — you do not write it.

You have been dispatched after all slices are done, integration tests pass, and the feature is functionally complete. Your job is to evaluate the full feature against the PRD and architectural standards — not to re-review individual slices (that was done slice-by-slice).

---

## Inputs You Receive

The orchestrator provides:

1. **plan.md** — complete plan with PRD, Domain Analysis, Pattern Library, and all slice definitions.
2. **All changed files** — the union of files_changed across all slices.
3. **Full test results** — from Phase 4 integration testing.
4. **.devflow/memory/** — architectural decisions, tech constraints, and established patterns for this project.

---

## What You Do

1. Read the PRD success criteria from plan.md.
2. Read all changed files holistically — look at the feature as a whole, not individual slices.
3. Verify the implementation actually delivers the PRD goals.
4. Check for architecture-level issues: consistency, security, data integrity, performance, maintainability.
5. Compare against `.devflow/memory/` for compliance with established architectural decisions.
6. Report APPROVED or CHANGES_REQUESTED with specific findings.

---

## Output Format

```
Verdict: APPROVED | CHANGES_REQUESTED

Feature Assessment:
[2-3 sentences: does the implementation deliver what the PRD requires?]

Findings:
CRITICAL: [architecture violations, security issues, data integrity risks, missing PRD requirements]
IMPORTANT: [performance issues, maintainability problems, consistency violations]
MINOR: [naming, style, non-urgent improvements]

Required Changes:
[Specific, actionable list. Empty if APPROVED.
 Each item: "fix X in Y because Z"]

Summary:
[2-3 sentences on what was built and your overall quality assessment]
```

**Verdict rules:**
- `APPROVED` — PRD requirements met, no CRITICAL findings, fewer than 2 IMPORTANT findings
- `CHANGES_REQUESTED` — any CRITICAL finding, OR 2+ IMPORTANT findings, OR PRD requirement not met

**Focus:** Architecture and feature completeness. Individual slice code quality was already reviewed slice-by-slice. Your scope is: does this feature work correctly, safely, and consistently as a whole?

---

## Constraints

- Review only — write no code.
- Focus on the full feature holistically, not per-slice quality.
- Be specific: "the Comment entity has no soft-delete, which violates the project's deletion policy in memory/decisions.md" is a finding. "could be better" is not.
AGENTEOF
```

- [ ] **Step 3: Commit both agents**

```bash
git add skills/feature/agents/integration-test.md skills/feature/agents/final-review.md
git commit -m "feat(feature-skill): add Integration Test and Final Review agent prompt templates"
```

---

## Task 8: Write skills/feature/SKILL.md (phases 0–2 + entry routing)

This is the main orchestrator. Write it in two tasks for manageability. Task 8 covers the preamble, entry routing, pre-flight, Phase 0, Phase 1, and Phase 2.

**Files:**
- Create: `skills/feature/SKILL.md`

- [ ] **Step 1: Write SKILL.md preamble through Phase 2**

Create `skills/feature/SKILL.md` with the following content:

````markdown
# Skill: feature

# DevFlow Feature Orchestration

Drive a feature from natural-language description to merged code via PRD interrogation, vertical slice planning, parallel subagent execution, integration testing, and architecture review.

**Invocation:**
- `/feature <description>` — full mode
- `/feature quick <description>` — abbreviated mode (fewer questions, sequential execution, no worktrees)
- `/feature resume` — resume an interrupted feature

**Spec:** `docs/superpowers/specs/2026-05-01-feature-skill-design.md`

---

## Pre-flight

Run before any user interaction (except: skip step 4 for `/feature resume`):

```bash
# 1. Verify DevFlow is initialized
ls .devflow/ 2>/dev/null || { echo "[DevFlow] .devflow/ not found. Run df-init first. (E01)"; exit 1; }

# 2. Verify memory is populated
ls .devflow/memory/ 2>/dev/null || { echo "[DevFlow] .devflow/memory/ missing. Run df-sync or df-init. (E02)"; exit 1; }

# 3. Run test suite — establish baseline health
# Run the project test command. On test failure: show failures, ask user to fix or proceed with baseline.
# Record results in plan.md § Baseline Health after plan folder is created.
# On BUILD failure (compile error, syntax error): HALT — do not proceed (E14).

# 4. Check for active feature (skip if command is /feature resume)
ls .devflow/active 2>/dev/null && { echo "[DevFlow] Active feature found. Use /feature resume or remove .devflow/active to start fresh. (E03)"; exit 1; } || true
```

---

## Entry Routing

After pre-flight, route based on the command:

| Command | Action |
|---------|--------|
| `/feature resume` | Jump to **Resume Algorithm** section |
| `/feature quick <desc>` | Set `quick_mode=true`, enter Phase 0 |
| `/feature <desc>` | Set `quick_mode=false`, enter Phase 0 |

---

## Phase 0: PRD Interrogation

Clarify the feature request before planning anything.

**Full mode:** Ask 3–6 clarifying questions, one at a time:
1. Who performs this action? (role/user type)
2. What is the observable, testable result? (what can the user see or do when done)
3. What is explicitly out of scope?
4. Are there performance or scale requirements?
5. Any dependencies on other features or systems?
6. What does failure look like? (error states, edge cases)

**Quick mode:** Ask 2–3 questions maximum (questions 1, 2, and 3 above).

After gathering answers, produce and present a structured PRD:

```markdown
## PRD: [Feature Name]

**Actor:** [user type]
**Goal:** [what they accomplish]
**Scope:** [what is included]
**Out of scope:** [explicitly excluded]
**Success criteria:** [observable, testable outcomes]
**Constraints:** [performance, security, compatibility requirements]
```

**STOPPING GATE — do not proceed until user approves:**
> "Does this PRD capture what you want to build? Approve or tell me what to change."

If rejected (E04): revise per feedback, re-present. Repeat until approved.

---

## Phase 1: Domain Analysis

Understand the codebase before planning slices.

**Steps:**

1. Run `df-explain` to load project structure:
   ```bash
   df-explain
   ```

2. Identify affected modules: directories, namespaces, services this feature will touch.

3. Identify a reference feature. Ask the user:
   > "I'll model the implementation patterns after [X feature] at [path]. Does that work, or is there a better reference?"
   
   If greenfield (no similar feature): use `.devflow/memory/` tech decisions + `CONTRIBUTING.md` if present.

4. Read ≤5 key files from the reference feature:
   - entity/model file
   - service file
   - controller/API handler file
   - frontend component file
   - test file
   
   Use `read` or file tool to read them directly.

5. Extract patterns as verbatim snippets (preserve exact formatting and naming conventions).

6. Identify risks:
   - DB migrations needed?
   - External service integrations?
   - Breaking API changes?
   - Parallel development conflicts with other branches?

Write domain analysis to `plan.md` (created in Phase 2, after stopping gate). Buffer the content now.

**plan.md Domain Analysis content to write:**
```markdown
## Domain Analysis

**Affected modules:** [list of directories/namespaces]
**Reference feature:** [feature name and path]
**Risks:** [bullet list]
**Dependencies:** [other features or systems this depends on]

## Pattern Library

### Entity Pattern
[verbatim entity code from reference feature]

### Service Pattern
[verbatim service code from reference feature]

### Controller/API Pattern
[verbatim controller code from reference feature]

### Frontend Pattern
[verbatim frontend component code from reference feature]

### Test Pattern
[verbatim test code from reference feature]
```

---

## Phase 2: Slice Planning

Decompose the approved PRD into vertical slices.

### What is a vertical slice?

A vertical slice is **thin, user-visible functionality** that cuts through ≥2 application layers and can be expressed as:

> **"[Actor] can [verb] [noun]"**

Examples:
- ✅ "User can create a comment" (hits DB + service + API + frontend)
- ✅ "Author can delete their story" (hits service + API + frontend)
- ❌ "Create all Comment entities" (layer-only, not a slice)
- ❌ "Build comment system" (too fat, not a slice)
- ❌ "Add CommentService" (single layer, not a slice)

**Litmus test:** Can you write a Playwright e2e test a non-developer could understand? If not → not a slice.

### Slice sizing checklist

Every slice must pass:

| Check | Criterion |
|-------|-----------|
| Size | 3–8 files, 3–10 steps, 100–300 line mission briefing |
| Verticality | Touches ≥2 layers (exception: pure DB migration slices) |
| Testability | Result expressible as "Actor can verb noun" |
| Independence | Dependencies on other slices, not on internal steps |
| Context fit | Slice MD + all touched files < 3000 lines total |
| Parallel safety | No conflicting file modifications (see below) |

### Parallel safety analysis

For each pair of slices in the same potential batch, compare their file lists:

- **ADDITIVE (safe):** Both slices add different lines to the same file (e.g., two new DI registrations, two new entity DbSets). These can parallelize.
- **CONFLICTING (must serialize):** Both slices modify the same function or method body. Add an artificial `depends_on` to force serialization. Document in plan.md § Dependency Notes.

### Build the plan

1. Decompose the PRD into 2–6 vertical slices.
2. For each slice, determine:
   - Which other slices it depends on (data dependencies)
   - Which slices it can parallelize with (no conflicting files)
   - Which layer(s) it touches
3. Assign slices to batches:
   - Independent slices → same batch (parallel)
   - Dependent slices → later batch (after dependency is done)

### Create plan folder and files

```bash
# Create plan folder
PLAN_SLUG="YYYY-MM-DD-<feature-slug>"   # use today's date + feature name kebab-case
mkdir -p ".devflow/plans/${PLAN_SLUG}"

# Create symlink
ln -sfn "plans/${PLAN_SLUG}" ".devflow/active"

# Create feature branch
git checkout -b "feature/<feature-slug>"
```

Write `plan.md`:

```markdown
# [Feature Name]

## PRD: [Feature Name]
[paste approved PRD here]

## Baseline Health
[test results from pre-flight: PASS (N/N) or list of pre-existing failures]

## Domain Analysis
[paste buffered domain analysis from Phase 1]

## Pattern Library
[paste buffered pattern library from Phase 1]

## Slice DAG

| Slice | Depends On | Parallel Safe With | Batch |
|-------|------------|-------------------|-------|
| slice-1-<slug> | none | slice-2-<slug> | 1 |
| slice-2-<slug> | none | slice-1-<slug> | 1 |
| slice-3-<slug> | slice-1 | — | 2 |

## Dependency Notes
[Any artificial dependencies added for parallel safety — document reason]

## Execution Batches

Batch 1 (parallel): slice-1-<slug>, slice-2-<slug>
Batch 2 (sequential): slice-3-<slug>

## Status: IN_PROGRESS
```

For each slice, write TWO files:

**`slice-N-<slug>.json`** (machine-readable):
```json
{
  "id": N,
  "name": "Actor can verb noun",
  "instructions": "slice-N-<slug>.md",
  "layers": ["db", "service", "api", "frontend"],
  "result": "Observable result description",
  "test_cmd": "playwright test --grep 'verb noun'",
  "depends_on": [],
  "status": "pending",
  "cycle": 0,
  "max_cycles": 3,
  "steps": [
    { "id": "s1", "action": "create|modify", "file": "path/to/file", "done": false }
  ],
  "test_steps": [
    { "id": "t1", "file": "tests/feature.spec.ts", "done": false }
  ],
  "implementation_summary": null,
  "files_changed": null,
  "test_result": null,
  "test_summary": null,
  "test_agent_skipped": false,
  "test_agent_skip_reason": null,
  "review_findings": null,
  "concerns": null,
  "worktree_path": null
}
```

**`slice-N-<slug>.md`** (agent mission briefing):
```markdown
# [Slice Name]

> **Agent Instructions:** You are implementing one vertical slice of a feature. Read this document
> completely before writing any code. Implement exactly what is described here,
> following the patterns shown. Leave a clean git commit when done.

## Goal

[One sentence: what user-visible result this slice achieves]

## Context

**Feature:** [Feature name]
**Slice:** [N of M]
**Dependencies:** [Other slice names that must be complete first, or "none"]
**Worktree:** [Path if parallel, or "feature/<slug> branch" if sequential]

## Code Patterns to Follow

[Copy ONLY the pattern sections relevant to this slice's layers from plan.md § Pattern Library]

## Steps

1. [Step using function/class name anchors, not line numbers]
   - [Sub-bullet: specific property or method details]

2. [Next step]

[Continue — 3 to 10 steps total]

## Expected Result

**Prerequisites:** [Which depends_on slices must be done, or "none"]
**Test command:** `[test_cmd]`
**Observable outcome:** [what the test verifies in plain English]

## Files Touched

| Action | File | Target |
|--------|------|--------|
| create | path/to/new-file.ext | — |
| modify | path/to/existing.ext | ClassName or function name |

## Dependencies

Slices that must be DONE before this one executes:
- [slice names, or "none"]
```

**Target:** 100–300 lines per slice MD. Max 400.

### Phase 2 Stopping Gate

Present the slice plan:

```
Slices planned (N total, M batches):

Batch 1 (parallel):
  ✦ slice-1: Actor can verb noun [layers]
  ✦ slice-2: Actor can verb noun [layers]

Batch 2:
  ✦ slice-3: Actor can verb noun [layers]
    └── depends on: slice-1

Approve to start execution, or tell me what to change.
```

If rejected (E05): ask "What would you change?" Adjust: merge/split/reorder/add slices. Regenerate only affected JSON+MD files. Re-present only changed slices.

**Quick mode:** Auto-generate 1–3 slices without full decomposition. Still requires the approval gate. If >3 slices are genuinely needed, warn: "This feature may be too large for quick mode. Continue anyway or switch to full mode?"
````

- [ ] **Step 2: Run a quick sanity check that the file looks right**

```bash
wc -l skills/feature/SKILL.md
head -5 skills/feature/SKILL.md
```

Expected: ~200+ lines, starts with `# Skill: feature`.

- [ ] **Step 3: Commit**

```bash
git add skills/feature/SKILL.md
git commit -m "feat(feature-skill): add SKILL.md phases 0-2 (PRD + domain analysis + slice planning)"
```

---

## Task 9: Complete SKILL.md with phases 3–6, resume algorithm, quick mode, and error reference

**Files:**
- Modify: `skills/feature/SKILL.md`

- [ ] **Step 1: Append Phase 3 through end of file**

Append the following to `skills/feature/SKILL.md`:

````markdown

---

## Phase 3: Slice Execution

Execute each batch in order. Within a batch, run slices in parallel (full mode) or sequentially (quick mode).

### Worktree setup (full mode, parallel batch only)

For each slice in the batch:

```bash
df-workspace create "feature/<feature-slug>-slice-<N>"
```

Record the worktree path in the slice JSON: `"worktree_path": "<path>"`.

**Sequential (quick mode or single-slice batch):** Direct commits to `feature/<feature-slug>`. No worktrees.

### Per-slice execution loop

For each slice in the batch:

```
LOOP (up to max_cycles times):

  1. IMPLEMENT
     
     Dispatch Implementation Agent:
       - Role file:   skills/feature/agents/implementation.md
       - Mission:     read slice-N-<slug>.md and paste full content
       - Context:     plan.md § Domain Analysis + § Pattern Library
       - Retry only:  prepend "## Prior Work" section (see format below)
     
     While dispatched:
       Update slice JSON: status=in_progress, cycle+=1
       Mark steps[].done=true as the agent reports each step complete
     
  2. TEST (conditional)
     
     Full mode: ALWAYS dispatch Test Agent.
     
     Quick mode: SKIP if ALL are true:
       - ≤2 steps in this slice
       - test_cmd passed
       - modifies existing behavior (not new user-facing feature)
     
     Quick mode: ALWAYS dispatch if ANY are true:
       - new user-facing behavior
       - no existing test coverage for this behavior
       - >3 files changed
     
     Dispatch Test Agent:
       - Role file:   skills/feature/agents/test.md
       - Mission:     slice-N-<slug>.md (Expected Result + test_steps sections)
       - Files:       files_changed list from Implementation Agent output
       - Patterns:    plan.md § Pattern Library (test pattern section)
     
     Record in slice JSON:
       test_summary: { tests_written, test_result, coverage_notes, concerns }
       test_agent_skipped: true/false
       test_agent_skip_reason: "..." (if skipped)
  
  3. REVIEW
     
     Dispatch Slice Review Agent:
       - Role file:   skills/feature/agents/slice-review.md
       - Spec:        slice-N-<slug>.md
       - Files:       read from files_changed paths on disk
       - Test result: slice JSON test_result field
       - Context:     plan.md § Domain Analysis
     
     If verdict=PASS:
       Update slice JSON: status=done
       Break loop (this slice is complete)
     
     If verdict=FAIL:
       Update slice JSON: review_findings={ verdict, critical, important, minor, required_changes }
       
       If cycle >= max_cycles:
         Update slice JSON: status=stuck
         Report to user (E06):
           "Slice N ([name]) is stuck after [max_cycles] cycles.
            Review findings: [required_changes list]
            Options: fix manually / skip this slice / abort feature"
         Wait for user direction. Break loop.
       Else:
         Continue loop (next cycle retries with Prior Work context)

END LOOP
```

**Prior Work section format (inject at top of Implementation Agent prompt on retry):**

```markdown
## Prior Work (Cycle N)

You are retrying this slice. Work was done in the previous cycle. Read existing files first.

**Files created/modified:**
- [path/to/file.ext] — [one-line description of what's there]

**Test result:** [PASS/FAIL] — [N/N tests passed, brief failure description]

**Review verdict:** FAIL

**Required fixes (do ONLY these):**
1. [Specific surgical instruction: what to fix in what file]
2. [Specific surgical instruction]

Read the existing files first. Fix only what is listed above. Do NOT re-implement from scratch.
```

### After each parallel batch

```bash
# Merge all slice branches into feature branch
git checkout feature/<feature-slug>
for each slice in batch:
  git merge "feature/<feature-slug>-slice-<N>"

# Handle conflicts
df-resolve   # for automated conflict resolution where possible
```

**Conflict types:**
- **Additive conflicts** (e.g., two DI registrations, two DbSet additions): auto-resolve by keeping both additions.
- **Non-additive conflicts** (same function body modified by two slices): escalate to user (E08). This indicates a planning error in Phase 2.

```bash
# Clean up worktrees
for each slice in batch:
  df-workspace destroy "feature/<feature-slug>-slice-<N>"
```

---

## Phase 4: Integration Testing

Run after ALL batches complete (even if some slices are stuck — report stuck slices first).

**Skip if:** quick mode AND single slice AND no stuck slices.

Dispatch Integration Test Agent:

```
- Role file: skills/feature/agents/integration-test.md
- All slice MDs: paste content of all slice-N-<slug>.md files
- plan.md: full content (PRD + batch structure)
- Changed files: union of all files_changed across all slices
```

If Integration Test Agent reports failures:
- Implement the fixes directly (orchestrator mode — make targeted code fixes)
- Re-run test suite
- If still failing: report to user (E09) with specific failing tests

On completion: append to `plan.md`:
```markdown
## Phase 4 Status: COMPLETE
[test results summary]
```

---

## Phase 5: Final Review

Dispatch Final Review Agent:

```
- Role file:     skills/feature/agents/final-review.md
- plan.md:       full content
- Changed files: all files changed across all slices (read from disk)
- Test results:  Phase 4 test summary
- Memory:        .devflow/memory/ directory contents
```

If verdict=CHANGES_REQUESTED:
- Show Required Changes to user
- Implement changes directly (orchestrator makes targeted fixes)
- Re-run full test suite
- Re-dispatch Final Review Agent
- If still CHANGES_REQUESTED after 2 cycles: escalate to user (E11)

On APPROVED: append to `plan.md`:
```markdown
## Phase 5 Status: COMPLETE
[Final Review summary]
```

---

## Phase 6: Completion

**Never skip this phase, even on abort.**

1. **Update memory:**
   ```bash
   df-sync
   ```

2. **Archive plan:**
   Update `plan.md` final line:
   ```markdown
   ## Status: COMPLETE
   ```
   (Keep the plan folder — it is the audit trail.)

3. **Remove active symlink:**
   ```bash
   rm .devflow/active
   ```

4. **Hand off to finishing-a-development-branch skill:**
   Invoke the `finishing-a-development-branch` skill to let the user decide how to merge/PR/cleanup.

### Abort Cleanup (any unrecoverable error or user abort)

1. Update `plan.md`: append `## Status: ABORTED`
2. `rm .devflow/active`
3. For each active worktree: `df-workspace destroy <name>`
4. Keep plan folder (audit trail)
5. Keep `feature/<slug>` branch (for manual recovery)

---

## Resume Algorithm (`/feature resume`)

1. Check `.devflow/active` symlink:
   ```bash
   ls .devflow/active
   ```
   If missing: check if a plan folder exists manually. If found, offer to recreate symlink. Otherwise: E10.

2. Read plan state:
   ```bash
   cat .devflow/active/plan.md
   ```
   Extract: feature name, PRD, batch structure.

3. Read all slice statuses:
   ```bash
   for f in .devflow/active/slice-*.json; do
     jq '{id, name, status, cycle}' "$f"
   done
   ```

4. Display resume summary:
   ```
   Resuming: [Feature Name]
   
   ✅ slice-1-create-comment (done, cycle 1)
   🔄 slice-2-list-comments (in_progress — step 3 of 5)
   ⏳ slice-3-delete-comment (pending)
   ⚠️  slice-4-edit-comment (stuck — cycle 3)
   
   Current batch: Batch 1
   Next batch: Batch 2 (waiting for Batch 1)
   ```

5. Find resume point:
   - Any `stuck` slices → report to user, ask for direction before resuming
   - Find first batch with `pending` or `in_progress` slices
   - For `in_progress` slices: show `steps[].done` flags, ask "restart from scratch or continue from step N?"

6. Resume Phase 3 from the identified batch.

7. **Edge cases:**
   - All slices `done` → resume at Phase 4
   - plan.md contains `## Phase 4 Status: COMPLETE` → resume at Phase 5
   - plan.md contains `## Phase 5 Status: COMPLETE` → run Phase 6

---

## Quick Mode Reference

Trigger: explicit `/feature quick <description>` only. Never auto-activate.

| Phase | Full Mode | Quick Mode |
|-------|-----------|------------|
| Phase 0 | 3–6 questions | 2–3 questions |
| Phase 1 | Full domain analysis | Same |
| Phase 2 | Full decomposition | Auto-generate 1–3 slices, still requires gate |
| Phase 3 | Parallel dispatch + worktrees | Sequential, direct commits |
| Test Agent | Always | Skip if ≤2 steps + test_cmd passed + modifies existing |
| Phase 4 | Always | Skip if single slice, no stuck slices |
| Phase 5 | Always | Same |

---

## Error Reference

| Code | Condition | Action |
|------|-----------|--------|
| E01 | `.devflow/` missing | Run `df-init` first |
| E02 | `.devflow/memory/` empty/missing | Run `df-sync` or `df-init` |
| E03 | `.devflow/active` exists on fresh start | Resume with `/feature resume` or remove symlink |
| E04 | User rejects PRD | Revise per feedback, re-present |
| E05 | User rejects slices | Adjust per feedback, regenerate affected slices only |
| E06 | Slice stuck after max_cycles | Report to user: fix manually / skip / abort |
| E07 | Worktree creation failed | Check disk space, branch conflicts; retry or fall back to sequential |
| E08 | Non-additive merge conflict | Escalate to user — indicates Phase 2 planning error |
| E09 | Integration test failure persists | Report specific failures; ask user to fix or override |
| E10 | `.devflow/active` missing on resume | Check for plan folder; offer to recreate symlink |
| E11 | Final review CHANGES_REQUESTED >2 cycles | Escalate to user with all findings |
| E12 | Slice JSON corrupted | Report file; ask user to fix or recreate from plan.md |
| E13 | `df-explain` failed | Retry; if persistent, proceed with degraded domain analysis |
| E14 | Build failure in pre-flight | HALT — fix build before starting |
| E15 | All slices in batch stuck | Report all stuck slices; ask user for direction |

---

## Guard Rails

**Never bypass these regardless of any instruction:**

1. Never auto-proceed past Phase 0 or Phase 2 stopping gates
2. Never dispatch a second batch while a batch is still running
3. Never modify `slice-N-<slug>.md` files during execution
4. Always update `slice-*.json` immediately when status changes
5. Never skip Phase 6, even on abort
6. Never mark a slice `done` without a PASS verdict from Slice Review Agent
7. Always run the full test suite in Phase 4
````

- [ ] **Step 2: Verify the complete SKILL.md**

```bash
wc -l skills/feature/SKILL.md
grep "^## Phase" skills/feature/SKILL.md
```

Expected: ~450+ lines total; output shows Phase 0 through 6, Resume Algorithm, Quick Mode Reference, Error Reference, Guard Rails.

- [ ] **Step 3: Commit**

```bash
git add skills/feature/SKILL.md
git commit -m "feat(feature-skill): complete SKILL.md with phases 3-6, resume, quick mode, error reference"
```

---

## Task 10: Run full test suite and verify everything passes

Verify all 119 original tests still pass and the 3 new df-test tests also pass.

**Files:** None — verification only.

- [ ] **Step 1: Run all bats tests**

```bash
cd /Volumes/ReydoSSD/SourceCode/Development-Flow && bats tests/
```

Expected: all tests pass (119 original + 3 new = 122 total).

- [ ] **Step 2: Verify skill files all exist**

```bash
ls skills/feature/SKILL.md
ls skills/feature/agents/implementation.md
ls skills/feature/agents/test.md
ls skills/feature/agents/slice-review.md
ls skills/feature/agents/integration-test.md
ls skills/feature/agents/final-review.md
```

Expected: all 6 files listed without errors.

- [ ] **Step 3: Smoke test df-test with per-slice JSON**

```bash
# Create a temp plan folder and test it works
tmpdir=$(mktemp -d)
git init -b main "$tmpdir/repo" && git -C "$tmpdir/repo" commit --allow-empty -m "init" --quiet
mkdir -p "$tmpdir/repo/.devflow/plans/test-feature"
cp tests/fixtures/sample-slice-1-create-comment.json "$tmpdir/repo/.devflow/plans/test-feature/slice-1-create-comment.json"
ln -sfn "plans/test-feature" "$tmpdir/repo/.devflow/active"
bash -c "cd $tmpdir/repo && $PWD/bin/df-test --list"
bash -c "cd $tmpdir/repo && $PWD/bin/df-test 1"
rm -rf "$tmpdir"
```

Expected: `--list` shows "User can create a comment", `df-test 1` prints PASS and exits 0.

- [ ] **Step 4: Final commit with summary**

```bash
git add .
git status  # verify nothing unexpected is staged
git commit -m "feat: implement feature skill (V5)

- skills/feature/SKILL.md: full 6-phase orchestration loop
  (PRD interrogation, domain analysis, slice planning,
   parallel execution with retry, integration testing, final review)
- skills/feature/agents/: 5 focused agent prompt templates
  (implementation, test, slice-review, integration-test, final-review)
- bin/df-test: per-slice JSON reading from .devflow/plans/ with
  backward-compatible slices.json fallback
- tests/: 3 new bats cases for per-slice JSON format
- fixtures: sample-slice-1, sample-slice-2, sample-plan.md"
```

---

## Self-Review

### Spec coverage check

The spec (`docs/superpowers/specs/2026-05-01-feature-skill-design.md`) defines:

| Spec section | Task that implements it |
|---|---|
| File structure (skills/feature/) | Tasks 4–9 |
| Slice JSON schema | Task 1 (fixture), Task 8 (SKILL.md template) |
| Slice MD template | Task 8 (SKILL.md) |
| Pre-flight | Task 8 (SKILL.md) |
| Phase 0 PRD interrogation | Task 8 (SKILL.md) |
| Phase 1 domain analysis | Task 8 (SKILL.md) |
| Phase 2 slice planning + gates | Task 8 (SKILL.md) |
| Phase 3 execution loop + retry | Task 9 (SKILL.md) |
| Phase 4 integration testing | Task 9 (SKILL.md) |
| Phase 5 final review | Task 9 (SKILL.md) |
| Phase 6 completion | Task 9 (SKILL.md) |
| /feature resume algorithm | Task 9 (SKILL.md) |
| Quick mode | Task 9 (SKILL.md) |
| 5 agent templates | Tasks 4–7 |
| Error reference (E01–E15) | Task 9 (SKILL.md) |
| Guard rails | Task 9 (SKILL.md) |
| df-test breaking change | Task 3 (bin/df-test) |
| df-test backward compatibility | Task 3 (bin/df-test) |
| 3 new bats tests | Task 2 (tests/df-test.bats) |

All spec requirements covered. ✅

### Placeholder scan

No "TBD", "TODO", or incomplete step — all steps show exact commands or file content. ✅

### Type/naming consistency

- Slice JSON field `worktree_path` used in Task 1 (fixture), Task 8 (SKILL.md template), Task 9 (SKILL.md Phase 3). ✅
- `df-workspace create/destroy` used consistently in Phase 3. ✅
- `plan.md` section headers (e.g., `## Phase 4 Status: COMPLETE`) used in Phase 4 write and resume edge case detection. ✅

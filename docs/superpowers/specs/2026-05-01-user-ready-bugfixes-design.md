# DevFlow — User-Ready Bug Fixes Design

**Date:** 2026-05-01
**Status:** Approved

---

## Goal

Fix all broken production paths and internal consistency issues identified in the audit so the DevFlow library works correctly for real users out of the box. AI enrichment stub remains in place (not in scope).

---

## Scope

7 targeted fixes across 3 shell scripts and 3 skill/phase markdown files. No new features. No refactoring beyond the specific defects listed.

---

## Fix A — `bin/df-resolve`: Schema alignment with `df-sync` writer

**Severity:** P0 — silent production breakage.

**Problem:**  
`df-sync` writes `graph_conflicts.json` with shape:
```json
{ "generated_at": "<sha>", "nodes": [...], "edges": [] }
```
`df-resolve` reads it using `.conflicts[]` in every jq expression. All conflict operations (list, accept, rewrite-intent verification) silently fail or produce wrong output.

**Fix:**  
`df-resolve` has two intertwined bugs against the real schema:

1. **Wrong top-level key:** `.conflicts[]` → `.nodes[]` (and `.conflicts | length` → `.nodes | length`)
2. **Wrong node ID field:** `.node_id` → `.id`
3. **Wrong branch value accessor:** `.branch_a.value` / `.branch_b.value` → `.branch_a` / `.branch_b` (plain strings)

Changes by line:

- Line 60: `jq '.conflicts | length'` → `jq '.nodes | length'`
- Lines 68–70: `.conflicts[]` → `.nodes[]`, `.node_id` → `.id`, `.branch_a.branch` / `.branch_b.branch` → omit (no branch metadata in real schema — display `.branch_a` / `.branch_b` values directly)
- Line 97: `[.conflicts[] | select(.node_id == $id)]` → `[.nodes[] | select(.id == $id)]`
- Lines 114, 116: `.conflicts[] | select(.node_id == $id) | .branch_a.value` → `.nodes[] | select(.id == $id) | .branch_a`
- Lines 128–130: `del(.conflicts[] | select(.node_id == $id))` → `del(.nodes[] | select(.id == $id))`
- Line 133: `.conflicts | length` → `.nodes | length`

**Schema of a node entry in `.nodes[]` (as written by `df-sync`):**
```json
{
  "id": "src/foo.ts",
  "conflict": "intent",
  "branch_a": "handles auth",
  "branch_b": "manages sessions"
}
```
Note: the node entry uses `id` (not `node_id`) and `branch_a`/`branch_b` are plain strings (not objects). All `df-resolve` jq selectors must use `.id` not `.node_id`.

**Tests:**  
Update `tests/df-resolve.bats`:
- Add a fixture `graph_conflicts.json` using the real `{nodes: [...]}` schema
- Assert `df-resolve --list` outputs the correct count and node IDs
- Assert `df-resolve --accept a <node-id>` succeeds and removes the entry from `.nodes`

---

## Fix B — `skills/feature/SKILL.md`: Stale pre-flight paths

**Severity:** P1 — pre-flight check passes when it should halt; incorrect path causes misleading error.

**Problem:**  
Pre-flight check 1 runs:
```bash
which df-init && ls .devflow/memory/ 2>/dev/null
```
Pre-flight check 2 halts if `.devflow/memory/` is empty or missing.

The path `.devflow/memory/` no longer exists. The real layout is `.devflow/branches/<branch>/` accessed via the `.devflow/active` symlink.

**Fix:**  
Replace pre-flight checks 1 and 2 in `SKILL.md`:

Check 1 (df-init check):
```bash
which df-init && test -d .devflow/
```
Halt condition: `.devflow/` does not exist.

Check 2 (memory check):
```bash
test -L .devflow/active && ls .devflow/active/
```
Halt condition: `.devflow/active` symlink missing or target directory empty/missing. Message: `"Memory is empty or uninitialized. Run /init to set up project memory."`

**Tests:**  
Static assertion test (skill-lint): verify the strings `.devflow/memory/` do NOT appear in `skills/feature/SKILL.md`. No bats script required — a `grep -c '.devflow/memory/' skills/feature/SKILL.md` returning `0` is the pass condition.

---

## Fix C — `bin/df-workspace`: Add `create` and `remove` subcommands for git worktrees

**Severity:** P1 — parallel worktree setup is completely broken.

**Problem:**  
`phase-3-execution.md` correctly calls:
```bash
df-workspace create feature/<feature-slug>-slice-N
df-workspace remove feature/<feature-slug>-slice-N
```
But `df-workspace` only implements `add / remove / list / read` for a workspace registry at `~/.devflow/workspaces/`. It has no `create` or `remove` subcommand that manages git worktrees.

**Rule motivation:** Git operations must stay in deterministic shell scripts — not AI-driven skills — for auditability and predictability.

**Fix:**  
Add two new subcommands to `bin/df-workspace`:

**`create <branch-name>`**  
Creates a git worktree at `.devflow/worktrees/<branch-name>` and checks out a new branch `<branch-name>`. Must be run from inside a git repository.

```bash
cmd_worktree_create() {
  local branch="$1"
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not a git repo."
    exit 1
  fi
  local root
  root="$(git rev-parse --show-toplevel)"
  local worktree_path="${root}/.devflow/worktrees/${branch}"
  if [[ -d "$worktree_path" ]]; then
    err "Worktree already exists at $worktree_path"
    exit 1
  fi
  mkdir -p "$(dirname "$worktree_path")"
  git worktree add "$worktree_path" -b "$branch"
  echo "[DevFlow] Worktree created: $worktree_path (branch: $branch)"
}
```

**`worktree-remove <branch-name>`**  
Removes the git worktree at `.devflow/worktrees/<branch-name>` and deletes the branch.

```bash
cmd_worktree_remove() {
  local branch="$1"
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "Not a git repo."
    exit 1
  fi
  local root
  root="$(git rev-parse --show-toplevel)"
  local worktree_path="${root}/.devflow/worktrees/${branch}"
  if [[ ! -d "$worktree_path" ]]; then
    err "Worktree not found: $worktree_path"
    exit 1
  fi
  git worktree remove "$worktree_path" --force
  git branch -D "$branch" 2>/dev/null || true
  echo "[DevFlow] Worktree removed: $worktree_path"
}
```

**Dispatch additions** (in the `case` block):
```bash
  create)
    if [[ $# -lt 2 ]]; then
      err "Usage: df-workspace create <branch-name>"
      exit 1
    fi
    cmd_worktree_create "$2"
    ;;
  worktree-remove)
    if [[ $# -lt 2 ]]; then
      err "Usage: df-workspace worktree-remove <branch-name>"
      exit 1
    fi
    cmd_worktree_remove "$2"
    ;;
```

Update the usage error message to include `create` and `worktree-remove`.

**Note on naming:** The existing `remove` subcommand removes a service from the registry (`df-workspace remove <workspace> <service>`). The new teardown command is named `worktree-remove` to avoid ambiguity.

**Stale `df-workspace remove` references to update** (the call `df-workspace remove feature/...` appears in three places — all must be updated to `df-workspace worktree-remove`):
- `skills/feature/phases/phase-3-execution.md` line 143 — Merge Parallel Slices teardown
- `skills/feature/SKILL.md` line 192 — Abort Cleanup Protocol step 3
- `skills/feature/phases/resume.md` line 115 — Abort Cleanup Protocol step 3 (duplicate; will be removed by Fix D)

**Tests:**  
In `tests/df-workspace.bats`:
- `create` in a temp git repo: assert worktree directory is created, branch exists
- `create` again with same name: assert error "Worktree already exists"
- `worktree-remove` after create: assert directory is gone, branch is deleted
- `worktree-remove` on non-existent branch: assert error "Worktree not found"

---

## Fix D — `skills/feature/phases/resume.md`: Duplicate content removal

**Severity:** P1 — maintenance trap, four sections duplicated from `SKILL.md`.

**Problem:**  
`resume.md` (lines 51–116) contains verbatim duplicates of four sections already in `skills/feature/SKILL.md`:
- Quick mode command summary table (lines 51–63 of `resume.md`)
- Error reference table E01–E15 (lines 65–96 of `resume.md`)
- Guard Rails (lines 98–108 of `resume.md`)
- Abort Cleanup Protocol (lines 110–116 of `resume.md`)

**Fix:**  
Remove all four duplicate blocks from `resume.md` (lines 51–116). Replace with a single reference line:

```
> For quick mode reference, error codes (E01–E15), guard rails, and abort cleanup protocol, see `skills/feature/SKILL.md`.
```

**Tests:**  
Two static assertions:
- `grep -c '| E01 |' skills/feature/phases/resume.md` returns `0` (error table gone)
- `grep -c 'Guard Rails' skills/feature/phases/resume.md` returns `0` (guard rails gone)

---

## Fix E — `bin/df-sync`: Prominent AI stub warning

**Severity:** P1 — silent degradation; graph enrichment produces empty intent without any user-visible notice.

**Problem:**  
When `DEVFLOW_AI_MOCK` is not set, `ai_batch()` emits a warning buried in verbose output and returns empty results. Users see nodes with no intent and don't know why.

**Fix:**  
At the start of `cmd_sync` (before `_do_sync` is called), add a one-time check:

```bash
if [[ "${DEVFLOW_AI_MOCK:-}" != "1" ]]; then
  err "Note: AI enrichment is not configured. Graph nodes will have no intent annotations."
  err "Set DEVFLOW_AI_MOCK=1 with DEVFLOW_AI_MOCK_FILE=<path> for testing."
fi
```

This runs once per sync invocation. It does not block the sync — it informs and continues.

**Tests:**  
In `tests/df-sync.bats`, add a test that runs `df-sync` without `DEVFLOW_AI_MOCK=1` and asserts stderr contains `"AI enrichment is not configured"`. Since `err()` writes to `>&2`, the bats test must capture stderr: use `run bash -c "df-sync 2>&1"` or equivalent to merge stderr into the captured output.

---

## Fix F — `skills/init/SKILL.md`: Field name inconsistency (`last_seen_sha` → `last_seen`)

**Severity:** P2 — documentation drift; any tooling or skill reading the documented schema will use the wrong field name.

**Problem:**  
`init/SKILL.md` documents the slice JSON schema with field `last_seen_sha`. `df-sync` writes the field as `last_seen`.

**Fix:**  
In `skills/init/SKILL.md`, rename `last_seen_sha` → `last_seen`. There are **two occurrences**: one in the nodes schema example (line 220) and one in the edges schema example (line 233). Both must be updated.

**Tests:**  
Static assertion: verify `last_seen_sha` does NOT appear in `skills/init/SKILL.md`. Pass: `grep -c 'last_seen_sha' skills/init/SKILL.md` returns `0`.

---

## Fix G — `bin/df-test`: `--list` does not support per-slice JSON format

**Severity:** P2 — `--list` produces stale/empty output for any feature created with the current toolchain.

**Problem:**  
`cmd_list` in `df-test` reads the legacy `slices.json` file. The current slice runner creates individual `slice-N-<slug>.json` files in the active plan directory. `--list` never finds them.

**Fix:**  
Update `cmd_list` in `bin/df-test`:

1. Check if the active plan directory contains any `slice-*.json` files
2. If yes: iterate over them, extract `name`, `status`, `test_result` from each, and display
3. If no: fall back to reading legacy `slices.json` (preserves backward compatibility)

Display format for the new per-slice mode:
```
[DevFlow] Active plan: <plan-name>
  slice-1-auth.json       auth setup          pending     —
  slice-2-ui.json         dashboard ui        done        PASS (4/4)
```

Note: the legacy `slices.json` fallback currently outputs `"Slice plan: $feature (approved $approved_at)"`. Keep the legacy format unchanged when falling back — do not unify the two display formats. The new per-slice format above is only used when `slice-*.json` files are found.

**Tests:**  
In `tests/df-test.bats`, add a fixture with two `slice-*.json` files in a temp active dir and assert `df-test --list` outputs both slice names.

---

## Files Touched

| File | Change |
|------|--------|
| `bin/df-resolve` | Fix all `.conflicts` → `.nodes` jq references, `.node_id` → `.id`, `.branch_a.value` → `.branch_a` |
| `bin/df-sync` | Add AI stub warning at top of `cmd_sync` |
| `bin/df-test` | Update `cmd_list` to read per-slice JSON format |
| `bin/df-workspace` | Add `create` and `worktree-remove` subcommands for git worktrees |
| `skills/feature/SKILL.md` | Fix pre-flight path checks 1 and 2; update Abort Cleanup Protocol `df-workspace remove` → `df-workspace worktree-remove` |
| `skills/feature/phases/phase-3-execution.md` | Update `df-workspace remove` teardown call to `df-workspace worktree-remove` |
| `skills/feature/phases/resume.md` | Remove all four duplicate sections (quick mode, error table, guard rails, abort cleanup) |
| `skills/init/SKILL.md` | Rename `last_seen_sha` → `last_seen` in schema example |
| `tests/df-resolve.bats` | Add real-schema fixture + --list and --accept tests |
| `tests/df-sync.bats` | Add AI warning assertion |
| `tests/df-test.bats` | Add per-slice --list fixture + assertion |
| `tests/df-workspace.bats` | Add create + worktree-remove tests |

---

## Out of Scope

- Real Claude API implementation in `ai_batch` (intentionally deferred)
- `df-explain --depth` BFS multi-hop (known stub, not user-blocking)
- Any new features beyond the `create`/`worktree-remove` subcommands

---

## Success Criteria

1. `df-resolve --list` outputs correct conflict count from a real `graph_conflicts.json`
2. `df-resolve --accept a <id>` resolves and removes the node from `.nodes`
3. `skills/feature/SKILL.md` pre-flight checks reference `.devflow/active/` correctly
4. `df-workspace create <branch>` creates a worktree at `.devflow/worktrees/<branch>`; `df-workspace worktree-remove <branch>` removes it
5. `resume.md` contains no duplicate error table, guard rails, or abort cleanup sections
6. Running `df-sync` without `DEVFLOW_AI_MOCK=1` prints a visible warning
7. `skills/init/SKILL.md` uses `last_seen` not `last_seen_sha`
8. `df-test --list` outputs slices from `slice-*.json` files
9. All existing bats tests continue to pass

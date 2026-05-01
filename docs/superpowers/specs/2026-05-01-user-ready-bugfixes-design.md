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

## Fix C — `skills/feature/phases/phase-3-execution.md`: Non-existent df-workspace subcommand

**Severity:** P1 — parallel worktree setup is completely broken.

**Problem:**  
Phase 3 calls:
```bash
df-workspace create feature/<feature-slug>-slice-N
df-workspace remove feature/<feature-slug>-slice-N
```
`df-workspace` only implements `add / remove / list / read` for a workspace registry at `~/.devflow/workspaces/`. It has no `create` subcommand and does not manage git worktrees at all.

**Fix:**  
Replace both calls in `phase-3-execution.md` with raw git commands:

Setup (Step 1):
```bash
git worktree add .devflow/worktrees/feature/<feature-slug>-slice-N -b feature/<feature-slug>-slice-N
```
Write the path `.devflow/worktrees/feature/<feature-slug>-slice-N` to `slice-N.json` → `worktree_path`.

Teardown (Merge Parallel Slices section):
```bash
git worktree remove .devflow/worktrees/feature/<feature-slug>-slice-N --force
```

**Tests:**  
Static assertion: verify the string `df-workspace create` does NOT appear in `skills/feature/phases/phase-3-execution.md`. Pass condition: `grep -c 'df-workspace create' skills/feature/phases/phase-3-execution.md` returns `0`.

---

## Fix D — `skills/feature/phases/resume.md`: Duplicate content removal

**Severity:** P1 — maintenance trap, two sources of truth for error codes and quick mode table.

**Problem:**  
`resume.md` contains verbatim duplicates of:
- The full error reference table (E01–E15)
- The quick mode command summary table

Both already exist in `skills/feature/SKILL.md`.

**Fix:**  
Remove the duplicate blocks from `resume.md`. Replace with a single reference line at the end of the file:

```
> For error codes (E01–E15) and quick mode reference, see `skills/feature/SKILL.md`.
```

**Tests:**  
Static assertion: verify `resume.md` does NOT contain `| E01 |` (first row of error table). Pass condition: `grep -c '| E01 |' skills/feature/phases/resume.md` returns `0`.

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
In `tests/df-sync.bats`, add a test that runs `df-sync` without `DEVFLOW_AI_MOCK=1` and asserts the output contains `"AI enrichment is not configured"`.

---

## Fix F — `skills/init/SKILL.md`: Field name inconsistency (`last_seen_sha` → `last_seen`)

**Severity:** P2 — documentation drift; any tooling or skill reading the documented schema will use the wrong field name.

**Problem:**  
`init/SKILL.md` documents the slice JSON schema with field `last_seen_sha`. `df-sync` writes the field as `last_seen`.

**Fix:**  
In `skills/init/SKILL.md`, find the slice JSON schema example and rename `last_seen_sha` → `last_seen`.

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

Display format (matches existing style):
```
[DevFlow] Active plan: <plan-name>
  slice-1-auth.json       auth setup          pending     —
  slice-2-ui.json         dashboard ui        done        PASS (4/4)
```

**Tests:**  
In `tests/df-test.bats`, add a fixture with two `slice-*.json` files in a temp active dir and assert `df-test --list` outputs both slice names.

---

## Files Touched

| File | Change |
|------|--------|
| `bin/df-resolve` | Fix all `.conflicts` → `.nodes` jq references |
| `bin/df-sync` | Add AI stub warning at top of `cmd_sync` |
| `bin/df-test` | Update `cmd_list` to read per-slice JSON format |
| `skills/feature/SKILL.md` | Fix pre-flight path checks 1 and 2 |
| `skills/feature/phases/phase-3-execution.md` | Replace `df-workspace create/remove` with `git worktree` |
| `skills/feature/phases/resume.md` | Remove duplicate error table and quick mode table |
| `skills/init/SKILL.md` | Rename `last_seen_sha` → `last_seen` in schema example |
| `tests/df-resolve.bats` | Add real-schema fixture + --list and --accept tests |
| `tests/df-sync.bats` | Add AI warning assertion |
| `tests/df-test.bats` | Add per-slice --list fixture + assertion |

---

## Out of Scope

- Real Claude API implementation in `ai_batch` (intentionally deferred)
- `df-explain --depth` BFS multi-hop (known stub, not user-blocking)
- `df-workspace` subcommand refactor (skill doc fix is sufficient)
- Any new features

---

## Success Criteria

1. `df-resolve --list` outputs correct conflict count from a real `graph_conflicts.json`
2. `df-resolve --accept a <id>` resolves and removes the node from `.nodes`
3. `skills/feature/SKILL.md` pre-flight checks reference `.devflow/active/` correctly
4. `phase-3-execution.md` uses `git worktree` commands with no mention of `df-workspace create`
5. `resume.md` contains no duplicate error table
6. Running `df-sync` without `DEVFLOW_AI_MOCK=1` prints a visible warning
7. `skills/init/SKILL.md` uses `last_seen` not `last_seen_sha`
8. `df-test --list` outputs slices from `slice-*.json` files
9. All existing bats tests continue to pass

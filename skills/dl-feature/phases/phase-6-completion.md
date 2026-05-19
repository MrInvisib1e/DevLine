# Phase 6: Completion

## Pre-flight

Before entering Phase 6:
- [ ] Phase 5 review returned PASS
- [ ] All slice JSONs have `status: "done"`
- [ ] `plan.md` shows all slices as complete

## Step 1 — Post-completion verification gate (T1/T2)

Run all verification commands from `config.json`:

```bash
# Run test_cmd
<test_cmd from config>

# Run build_cmd if present
<build_cmd if present>

# Run lint_cmd if present
<lint_cmd if present>
```

### Verification Result Table

| Result | Action |
|--------|--------|
| All pass | → proceed to Step 2 |
| test_cmd fails | → route back to Phase 3 with test failure output |
| build_cmd fails | → route back to Phase 3 with build error |
| lint_cmd fails | → T2 Inform, proceed (lint is non-blocking) |
| 3rd failure routed back | → T3 Gate: show all failures, present `dl:choice` for direction |
| DEFAULT | → T2 Inform failures, attempt 1 more sync |

When the 3rd failure row is hit, present this gate:

```dl:choice
question: Verification failed 3 times. How do you want to proceed?
options:
  - label: Route back to Phase 3
    description: Send failures to implementation agents to fix
  - label: Skip failing checks
    description: Mark checks as acceptable and proceed with current state
  - label: Abort feature
    description: Stop the feature run and leave branch as-is
```

CHECKPOINT: "[Devline] Verification complete: all commands passed"

## Step 2 — Memory sync (T1)

Run:
```bash
dl-init --write-memory --force
```

T2 Inform: `[Devline] Memory synced: <sha>`

## Step 3 — Archive plan (T1)

Move the active plan to archive:
```bash
mv .devline/plans/<plan-slug>/ .devline/plans/archive/<plan-slug>-$(date +%Y%m%d)/
```

T2 Inform: `[Devline] Plan archived: <plan-slug>`

## Step 4 — T3: Completion strategy gate

Determine base branch:
```bash
BASE=$(git merge-base HEAD main 2>/dev/null && echo main || echo master)
```

Present a `dl:choice` gate:

```dl:choice
question: Feature complete. All tests pass. How do you want to integrate this work?
options:
  - label: Merge now
    description: git merge --no-ff into {base} immediately
  - label: Open a PR
    description: Push branch and create PR via gh pr create
  - label: Keep branch
    description: Stay on current branch for later review or merge
  - label: Discard
    description: Delete the feature branch (requires confirmation)
default: Merge now
```

Wait for response. Then execute the chosen option per the Completion Option Table below.

### Completion Option Table

| Choice | Action |
|--------|--------|
| A | `git checkout <base> && git pull && git merge --no-ff feature/<name> -m "feat: <feature-name>"` → run tests → cleanup |
| B | `git push -u origin feature/<name>` → `gh pr create --title "<feature-name>" --body "Closes #<issue>"` |
| C | T2 Inform: `[Devline] Branch kept: <branch-name>. PR or merge when ready.` |
| D | Ask: "Type 'discard' to confirm." → on confirmation: `git checkout <base> && git branch -D feature/<name>` → cleanup |
| DEFAULT | → A (merge now) |

## Step 5 — Record completion (T1)

Append to `.devline/history.json` (create if doesn't exist):

```json
{
  "feature": "<feature-name>",
  "branch": "<branch-name>",
  "completed_at": "<ISO timestamp>",
  "completion_strategy": "<A|B|C|D>",
  "plan_archived": "<archive-path>"
}
```

CHECKPOINT: "[Devline] Feature <name> complete and recorded"

## Step 6 — Cleanup (T1)

### Worktree + Branch Cleanup

| Choice | Worktree | Branch | Action |
|--------|----------|--------|--------|
| A (Merge) | Remove | Delete | `git worktree remove <path>` → `git branch -d feature/<name>` |
| B (PR) | Keep | Keep | Worktree preserved for PR review |
| C (Keep) | Keep | Keep | No cleanup |
| D (Discard) | Remove | Force-delete | `git worktree remove <path>` → `git branch -D feature/<name>` |

### Artifact Cleanup (T1 Silent)

Clean up stale session artifacts:
```bash
# Remove session logs older than 30 days
find .devline/sessions/ -name "*.jsonl" -mtime +30 -delete 2>/dev/null || true

# Remove archived plans older than 90 days
find .devline/plans/archive/ -maxdepth 1 -mtime +90 -type d -exec rm -rf {} + 2>/dev/null || true
```

T1 Silent — cleanup only.

## Step 7 — Clean up active symlink (T1)

Remove the active plan symlink if it points to the now-archived plan.
```bash
ls -la .devline/plans/active 2>/dev/null || true
```

T1 Silent — cleanup only.

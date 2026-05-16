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
| 3rd failure routed back | → T3 Gate: show failures, ask for direction |
| DEFAULT | → T2 Inform failures, attempt 1 more sync |

CHECKPOINT: "[DevFlow] Verification complete: all commands passed"

## Step 2 — Memory sync (T1)

Run:
```bash
df-init --write-memory --force
```

T2 Inform: `[DevFlow] Memory synced: <sha>`

## Step 3 — Archive plan (T1)

Move the active plan to archive:
```bash
mv .devflow/plans/<plan-slug>/ .devflow/plans/archive/<plan-slug>-$(date +%Y%m%d)/
```

T2 Inform: `[DevFlow] Plan archived: <plan-slug>`

## Step 4 — T3: Completion strategy gate

Present:
```
[DevFlow] Feature complete. All tests pass. Memory synced.

How do you want to integrate this work?

  [A] Merge into main now (git merge --no-ff)
  [B] Open a PR (creates PR via gh pr create)
  [C] Keep branch for review (just stay on current branch)

What's your choice?
```

Wait for response. Execute the chosen option.

### Completion Option Table

| Choice | Action |
|--------|--------|
| A | `git checkout main && git merge --no-ff feature/<name> -m "feat: <feature-name>"` |
| B | `gh pr create --title "<feature-name>" --body "Closes #<issue-if-known>"` |
| C | T2 Inform: `[DevFlow] Branch kept: <branch-name>. PR or merge when ready.` |
| DEFAULT | → A (merge now) |

## Step 5 — Record completion (T1)

Append to `.devflow/history.json` (create if doesn't exist):

```json
{
  "feature": "<feature-name>",
  "branch": "<branch-name>",
  "completed_at": "<ISO timestamp>",
  "completion_strategy": "<A|B|C>",
  "plan_archived": "<archive-path>"
}
```

CHECKPOINT: "[DevFlow] Feature <name> complete and recorded"

## Step 6 — Clean up active symlink (T1)

Remove the active plan symlink if it points to the now-archived plan.
```bash
# Remove active plan pointer if stale
ls -la .devflow/plans/active 2>/dev/null || true
```

T1 Silent — cleanup only.

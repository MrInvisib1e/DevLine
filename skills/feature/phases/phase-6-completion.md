## Phase 6: Completion

Goal: sync memory, archive the plan, and hand off to finishing-a-development-branch.

### Step 1: Memory Sync

```bash
df-sync
```

If df-sync fails: warn but continue (don't abort completion).

### Step 2: Archive Plan

Update `plan.md`:
- Add `## Completion` section with timestamp
- Update overall status: `COMPLETE` (or `COMPLETE_WITH_STUCK_SLICES` if any stuck)
- List stuck slices if any (for follow-up)

The plan folder remains as an audit trail. Do NOT delete it.

### Step 3: Remove Active Symlink

```bash
rm .devflow/active
```

This marks the feature as no longer in-progress.

### Step 4: Hand Off

Invoke the `finishing-a-development-branch` skill. This skill handles the merge/PR/cleanup decision — do not make that decision yourself.

Present a summary to the user:

```
## Feature Complete: <Feature Name>

**Slices:** N done, M stuck (if any)
**Tests:** X passing, Y failing (if any)
**Branch:** feature/<feature-slug>

[finishing-a-development-branch will guide you through merge/PR options]
```

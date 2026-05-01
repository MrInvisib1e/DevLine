## /feature resume

### Step 1: Check for Active Plan

```bash
readlink .devflow/active
```

If `.devflow/active` does not exist: error E10 — "No active feature found. Use `/feature <description>` to start one."

If it exists but the target directory is missing: try to find the plan by listing `.devflow/plans/` and ask user which to resume.

### Step 2: Load Plan State

Read `plan.md` — extract:
- Feature name
- PRD
- Domain Analysis
- Execution batches

Read all `slice-N-*.json` files — build status map.

### Step 3: Find Resume Point

Scan batches in order:

1. Any slices `stuck`? → Report them to user before resuming
2. Find the **first batch** that has `pending` or `in_progress` slices
3. For `in_progress` slices: check `steps[].done` — show progress, offer to restart or continue from last done step
4. All slices `done`? → Check `plan.md` for `## Phase 4 Status`:
   - Missing or not COMPLETE → resume at Phase 4
   - COMPLETE → check `## Phase 5 Status`: not COMPLETE → resume at Phase 5
   - Phase 5 COMPLETE → run Phase 6

### Step 4: Show Resume Status

```
## Resuming: <Feature Name>

| Slice | Status | Progress |
|-------|--------|----------|
| 1: User can create comment | ✅ done | — |
| 2: User can list comments | 🔄 in_progress | Step 2/5 done |
| 3: User can delete comment | ⏳ pending | — |

**Resuming at:** Slice 2 (continuing from Step 3)
**Next batch:** Slice 3 (after Slice 2 completes)
```

Confirm with user, then resume Phase 3 at the identified slice.

### Edge Cases

- `.devflow/active` symlink points to non-existent directory: list `.devflow/plans/` and ask user which to resume
- All slices done but no active symlink: plan is archived — can't resume (suggest `/feature <desc>` for new work)
- All slices stuck: report to user and ask for direction

---

## Quick Mode

Triggered by explicit `/feature quick <description>` invocation only. Never auto-activate.

| Phase | Full Mode | Quick Mode |
|-------|-----------|------------|
| Phase 0 | 3–6 clarifying questions | 2–3 questions |
| Phase 1 | Full domain analysis | Same |
| Phase 2 | Full decomposition | Auto-generate 1–3 slices, still requires approval |
| Phase 3 | Parallel dispatch, worktrees | Always sequential, direct commits, no worktrees |
| Test Agent | Always dispatch | Skip if: ≤2 steps + test_cmd passed + modifying existing behavior |
| Phase 4 | Always | Skip if single slice and no stuck slices |
| Phase 5 | Always | Same |

**Quick mode boundary:** If analysis during Phase 2 reveals >3 slices are genuinely needed, warn the user: "This feature may require more than 3 slices — quick mode auto-limits to 3 most important. Continue with quick mode (auto-slim to 3) or switch to full mode?" Wait for answer before proceeding.

---

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | df-init not run — `.devflow/` missing | HALT — "Run `/init` first" |
| E02 | Memory empty — `.devflow/memory/` missing or empty | HALT — "Run df-init to set up project memory" |
| E03 | Active plan exists on fresh `/feature` start | HALT — "Use `/feature resume` or delete `.devflow/active` to abort" |
| E04 | User rejects PRD | Revise and re-present |
| E05 | User rejects slices | Adjust and re-present |
| E06 | Slice stuck (max cycles exceeded) | Mark stuck, continue independent slices, report to user |
| E07 | All slices in batch stuck | Pause, report to user, ask for direction |
| E08 | Worktree creation fails | Report error, ask to retry or use sequential mode |
| E09 | Merge conflict unresolvable | Run df-resolve, escalate to user |
| E10 | `/feature resume` with no active plan | HALT — "No active feature. Use `/feature` to start one" |
| E11 | Final review CHANGES_REQUESTED | Re-open affected slices, re-run; escalate to user after >2 cycles |
| E12 | Slice JSON corrupted or unreadable | Report specific file; ask user to fix or reset slice |
| E13 | df-explain fails | Warn and proceed with degraded analysis |
| E14 | Integration test persistent failure | Report specific failures; ask user to fix or override |
| E15 | Build fails at pre-flight | HALT — "Fix build errors before starting a new feature" |

### Guard Rails

These rules are ABSOLUTE — never override:

1. **Never auto-proceed past a STOPPING GATE.** Always wait for user approval.
2. **Never dispatch two batches simultaneously.**
3. **Never modify slice MD files during execution.** They are the spec.
4. **Always update slice JSON immediately** after each agent completes.
5. **Never skip Phase 6.** Memory sync and cleanup must happen.
6. **Never remove `.devflow/plans/` folders.** They are audit trails.
7. **If unsure about scope:** stop and ask. Don't guess.

### Abort Cleanup Protocol

On any unrecoverable error or user abort:
1. Update `plan.md` status → `ABORTED`
2. Remove `.devflow/active` symlink
3. Clean up worktrees (`df-workspace remove` for each active worktree)
4. Keep plan folder as audit trail
5. Keep `feature/<slug>` branch (for manual recovery)

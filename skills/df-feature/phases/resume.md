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

### Resume Point Decision Table

| State found in plan.md | Action |
|-----------------------|--------|
| Phase 6 complete | → T2 Inform: feature already complete |
| Phase 5: PASS recorded | → resume at Phase 6 |
| Phase 4: PASS recorded | → resume at Phase 5 |
| Phase 3: all slices DONE/PASS | → resume at Phase 4 |
| Phase 3: some slices in progress | → read steps[].done for those slices, resume within Phase 3 |
| Phase 2: slices defined, none started | → resume at Phase 3 |
| Phase 0/1: no slices defined | → resume at Phase 0 |
| plan.md missing or empty | → HALT. Print: "Cannot resume — no plan found. Start fresh with /feature." |
| DEFAULT | → resume at earliest incomplete phase |

CHECKPOINT: "[DevFlow] Resuming at: Phase <N>, Slice <name if applicable>"

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

> For quick mode reference, error codes (E01–E15), guard rails, and abort cleanup protocol, see [skills/df-feature/SKILL.md](../SKILL.md).

---
name: devflow-feature
description: Use when building a new feature that requires PRD, domain analysis, vertical slice planning, and agent-driven execution with graph memory
---

# Skill: feature

# DevFlow Feature Skill

Orchestrate a feature from idea to merged code. Drives PRD interrogation, domain analysis, slice planning, parallel agent execution, testing, review, and clean completion.

**Invoked as:** `/feature <description>`, `/feature quick <description>`, or `/feature resume`

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `/feature <description>` | Start a new feature (full mode) |
| `/feature quick <description>` | Start a new feature (quick mode — fewer questions, 1-3 slices) |
| `/feature resume` | Resume an in-progress feature |

---

## Pre-Flight

Run these checks before anything else. Do not proceed if any fail.

**1. df-init check**

```bash
which df-init && ls .devflow/memory/ 2>/dev/null
```

If `.devflow/` does not exist: HALT — "Run `/init` first to initialize DevFlow."

**2. Memory check**

If `.devflow/memory/` is empty or missing: HALT — "Memory is empty. Run `/init` to set up project memory."

**3. Active plan check** (skip if command is `/feature resume`)

```bash
ls -la .devflow/active 2>/dev/null
```

If `.devflow/active` symlink exists: HALT — "A feature is already in progress. Use `/feature resume` to continue, or delete `.devflow/active` to start fresh."

**4. Pre-flight build check**

Read the test command from `.devflow/memory/` (check for `test_cmd` in config or memory files). Run it:

```bash
<test_cmd>
```

- If build fails (compile error): HALT — "Fix build errors before starting a new feature." (error E15)
- If tests fail (runtime failures, not compile): show failures, ask: "Fix these first, or proceed with this baseline? (failures will be tracked)" If proceeding: record failures in `plan.md` under `## Baseline Health`.

---

## Entry Routing

Parse the user's command:

- `/feature resume` → read `phases/resume.md` and follow it
- `/feature quick <description>` → set `QUICK_MODE=true`, read `phases/phase-0-prd.md`
- `/feature <description>` → set `QUICK_MODE=false`, read `phases/phase-0-prd.md`
- No description provided → ask: "What feature are you building?"

---

## Phase Dispatch

Read ONLY the phase file you need right now. Do not pre-load future phases.

| Phase | File | When to load |
|-------|------|-------------|
| 0: PRD | `skills/feature/phases/phase-0-prd.md` | After entry routing |
| 1: Domain | `skills/feature/phases/phase-1-domain.md` | After PRD approved |
| 2: Slices | `skills/feature/phases/phase-2-slices.md` | After domain analysis |
| 3: Execution | `skills/feature/phases/phase-3-execution.md` | After slices approved |
| 4: Integration | `skills/feature/phases/phase-4-integration.md` | After all batches done |
| 5: Review | `skills/feature/phases/phase-5-review.md` | After integration |
| 6: Completion | `skills/feature/phases/phase-6-completion.md` | After review approved |
| Resume | `skills/feature/phases/resume.md` | On `/feature resume` |

---

## Quick Mode Summary

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

---

## Guard Rails

These rules are ABSOLUTE — never override:

1. **Never auto-proceed past a STOPPING GATE.** Always wait for user approval.
2. **Never dispatch two batches simultaneously.**
3. **Never modify slice MD files during execution.** They are the spec.
4. **Always update slice JSON immediately** after each agent completes.
5. **Never skip Phase 6.** Memory sync and cleanup must happen.
6. **Never remove `.devflow/plans/` folders.** They are audit trails.
7. **If unsure about scope:** stop and ask. Don't guess.

---

## Abort Cleanup Protocol

On any unrecoverable error or user abort:
1. Update `plan.md` status → `ABORTED`
2. Remove `.devflow/active` symlink
3. Clean up worktrees (`df-workspace remove` for each active worktree)
4. Keep plan folder as audit trail
5. Keep `feature/<slug>` branch (for manual recovery)

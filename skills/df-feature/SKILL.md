---
name: devflow-feature
description: Full feature lifecycle — PRD → domain → slices → implement → review → completion
requires: [df-sync]
triggers_on_complete: [df-verify]
---

# /df-feature — Full Feature Lifecycle

Orchestrate a feature from idea to merged code. Drives PRD interrogation, domain analysis, slice planning, parallel agent execution, testing, review, and clean completion.

**Invoked as:** `/df-feature <description>`, `/df-feature quick <description>`, or `/df-feature resume`

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `/df-feature <description>` | Start a new feature (full mode) |
| `/df-feature quick <description>` | Quick mode — fewer questions, 1-3 slices |
| `/df-feature resume` | Resume an in-progress feature |

---

## Iron Law

```
NO CODE WITHOUT APPROVED SLICES. NO MERGE WITHOUT PASSING REVIEW.
```

Haven't passed a stopping gate → cannot proceed. Period.

---

## Pre-Flight

Run these checks before anything else. Do not proceed if any fail.

**1. df-init check**

```bash
which df-init && test -d .devflow/
```

If `.devflow/` does not exist: HALT — "Run `/df-init` first to initialize DevFlow."

**2. Memory freshness (T1 Silent)**

```bash
LAST=$(python3 -c "import json; print(json.load(open('.devflow/config.json')).get('last_synced',''))" 2>/dev/null)
HEAD=$(git rev-parse HEAD)
```

If stale: run `/df-sync` (T1 Silent).

**3. Active plan check** (skip if command is `/df-feature resume`)

```bash
ls .devflow/plans/ 2>/dev/null | grep -v "^$"
```

If an active (non-completed) plan exists: HALT — "A feature is in progress. Use `/df-feature resume` or delete the plan to start fresh."

**4. Pre-flight build check**

Read `test_cmd` from `.devflow/config.json`. Run it:
```bash
<test_cmd>
```

- If compile error: HALT — "Fix build errors before starting a new feature." (error E15)
- If tests fail: show failures, ask: "Fix these first, or proceed tracking this baseline?" If proceeding: record in plan.md under `## Baseline Health`.

---

## Entry Routing

| Command | Action |
|---------|--------|
| `/df-feature resume` | Read `skills/df-feature/phases/resume.md` and follow it |
| `/df-feature quick <desc>` | Set `QUICK_MODE=true`, read `phases/phase-0-prd.md` |
| `/df-feature <desc>` | Set `QUICK_MODE=false`, read `phases/phase-0-prd.md` |
| No description | Ask: "What feature are you building?" |

---

## Phase Dispatch

Read ONLY the phase file you need right now. Do not pre-load future phases.

| Phase | File | When to load |
|-------|------|-------------|
| 0: PRD | `skills/df-feature/phases/phase-0-prd.md` | After entry routing |
| 1: Domain | `skills/df-feature/phases/phase-1-domain.md` | After PRD approved |
| 2: Slices | `skills/df-feature/phases/phase-2-slices.md` | After domain analysis |
| 3: Execution | `skills/df-feature/phases/phase-3-execution.md` | After slices approved |
| 4: Integration | `skills/df-feature/phases/phase-4-integration.md` | After all batches done |
| 5: Review | `skills/df-feature/phases/phase-5-review.md` | After integration |
| 6: Completion | `skills/df-feature/phases/phase-6-completion.md` | After review approved |
| Resume | `skills/df-feature/phases/resume.md` | On `/df-feature resume` |

**REQUIRED:** Before marking any slice done or claiming feature complete, follow `skills/df-verify/SKILL.md`.

---

## Quality Hooks (Phase 3)

After each file write during execution:

Run `df-check`:
- Exit 1 (type error) = **BLOCK** — fix types before proceeding
- Exit 2 (lint/format issues) = **ADVISORY** — auto-fix applied, continue
- Exit 0 = pass, continue

---

## Quick Mode Summary

| Phase | Full Mode | Quick Mode |
|-------|-----------|------------|
| Phase 0 | 3–6 clarifying questions | 2–3 questions |
| Phase 1 | Full domain analysis | Same |
| Phase 2 | Full decomposition | Auto-generate 1–3 slices, still requires approval |
| Phase 3 | Parallel dispatch, worktrees | Sequential, direct commits, no worktrees |
| Test Agent | Always dispatch | Skip if: ≤2 steps + test_cmd passed + modifying existing behavior |
| Phase 4 | Always | Skip if single slice and no stuck slices |
| Phase 5 | Always | Same |

**Quick mode boundary:** If Phase 2 reveals >3 slices are genuinely needed, warn user: "This feature needs more than 3 slices — quick mode auto-limits to 3. Continue with quick mode or switch to full mode?" Wait for answer.

---

## Phase 6 — Completion Options

Present 4 options to user (T3 Gate):

| Option | Action |
|--------|--------|
| 1. Merge to base branch locally | Switch → pull → merge → verify tests → delete branch |
| 2. Push and create Pull Request | Push with -u flag → create PR with title + body |
| 3. Keep branch as-is | Report branch preserved, no cleanup |
| 4. Discard | Require typed "discard" confirmation → force-delete branch |

Run `/df-init --write-memory` after any merge to update memory.

---

## Guard Rails

These rules are ABSOLUTE — never override:

1. **Three T3 gates. No more.** Only: PRD approval (Phase 0), slice plan approval (Phase 2), completion strategy (Phase 6).
2. **T2 for mid-execution judgments.** Scope ambiguity, concerns → T2 Inform with assumption. Don't pause.
3. **T1 for mechanical steps.** Worktree creation, config writes, memory sync calls.
4. **Never dispatch two batches simultaneously.**
5. **Never modify slice MD files during execution.** They are the spec.
6. **Always update slice JSON immediately** after each agent completes.
7. **Never skip Phase 6.** Memory sync and cleanup must happen.
8. **Never remove `.devflow/plans/` folders.** They are audit trails.
9. **Scope ambiguous:** T2 Inform — state assumption, proceed.
10. **Reality check.** Code that works, follows conventions, passes tests — done.

---

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | `.devflow/` missing | HALT — "Run `/df-init` first" |
| E03 | Active plan exists on fresh start | HALT — "Use `/df-feature resume` or delete plan" |
| E04 | User rejects PRD | Revise and re-present |
| E05 | User rejects slices | Adjust and re-present |
| E06 | Slice stuck (max cycles exceeded) | Mark stuck, continue independent slices, report |
| E07 | All slices in batch stuck | Pause, T3 Gate — report to user, ask direction |
| E08 | Worktree creation fails | Report error, ask to retry or use sequential mode |
| E10 | `/df-feature resume` with no active plan | HALT — "No active feature. Use `/df-feature` to start one" |
| E11 | Final review FAIL | Re-open affected slices, re-run; escalate after >2 cycles |
| E13 | df-explain fails | T2 Warn and proceed with degraded analysis |
| E15 | Build fails at pre-flight | HALT — "Fix build errors before starting a new feature" |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "User impatient, skip gate" | Skip gate → rework. Run it. |
| "PRD obvious, no need to ask" | Obvious PRDs have hidden assumptions. Ask. |
| "Just one slice, skip integration" | Single slices still need Phase 5 review. |
| "Minor issues, ship anyway" | Minor issues compound. Fix them. |
| "Tests pass, skip review agent" | Tests = behavior. Review = architecture. Both. |
| "Quick mode = less rigor" | Fewer questions. Not fewer checks. |
| "While I'm here, fix this too" | Out of scope. Works. Leave it. |

## Red Flags — STOP

- Code before slice approval
- "Gate doesn't apply here"
- Skipping a phase because "obvious"
- Next batch dispatched before current batch review done
- Modifying slice MD during execution
- About to merge without Phase 5
- "Quick mode means skip this"
- Type errors during df-check — do not push past them

**Stop. Re-read guard rails. Follow the process.**

---

## Abort Cleanup Protocol

On any unrecoverable error or user abort:
1. Update `plan.md` status → `ABORTED`
2. Clean up worktrees (`df-workspace worktree-remove` for each active worktree)
3. Keep plan folder as audit trail
4. Keep `feature/<slug>` branch (for manual recovery)

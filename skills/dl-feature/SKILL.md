---
name: devline-feature
description: Full feature lifecycle — PRD → domain → slices → implement → review → completion
requires: [dl-sync]
triggers_on_complete: [dl-verify]
---

# /dl-feature — Full Feature Lifecycle

Orchestrate a feature from idea to merged code. Drives PRD interrogation, domain analysis, slice planning, parallel agent execution, testing, review, and clean completion.

**Invoked as:** `/dl-feature <description>`, `/dl-feature quick <description>`, or `/dl-feature resume`

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `/dl-feature <description>` | Start a new feature (full mode) |
| `/dl-feature quick <description>` | Quick mode — fewer questions, 1-3 slices |
| `/dl-feature resume` | Resume an in-progress feature |

---

## Iron Law

```
NO CODE WITHOUT APPROVED SLICES. NO MERGE WITHOUT PASSING REVIEW.
```

Haven't passed a stopping gate → cannot proceed. Period.

---

## Pre-Flight

**Shared definitions:** Load `skills/_shared.md` now. It defines T1/T2/T3 tiers, SIF rules, the Session Audit Log, and the Unified Status Model. All rules in this file assume those definitions are in context. — because guard rails reference T1/T2/T3 but those tiers are defined only in `_shared.md`; if it is not loaded, the model infers their meaning and produces inconsistent behavior.

Run these checks before anything else. Do not proceed if any fail.

**1. dl-init check**

```bash
which dl-init && test -d .devline/
```

If `.devline/` does not exist: HALT — "Run `/dl-init` first to initialize Devline."

**2. Memory freshness (T1 Silent)**

```bash
LAST=$(python3 -c "import json; print(json.load(open('.devline/config.json')).get('last_synced',''))" 2>/dev/null)
HEAD=$(git rev-parse HEAD)
# Stale = last_synced SHA does not exactly match current HEAD SHA
if [ "$LAST" != "$HEAD" ]; then run dl-sync; fi
```

Both `last_synced` and HEAD are git commit SHAs. Stale = they do not match exactly. — because without an explicit comparison, "if stale" is ambiguous and the model may rationalize "close enough" and skip the sync.

If stale: run `/dl-sync` (T1 Silent). T2 Inform: "[Devline] Memory was stale — synced to {HEAD}".

**3. Active plan check** (skip if command is `/dl-feature resume`)

Read `mode` from `.devline/config.json`.

| Mode | Active plan rule |
|------|-----------------|
| `project` | If any non-COMPLETED/non-ABORTED plan exists → HALT: "A feature is in progress. Use `/dl-feature resume` or delete the plan to start fresh." |
| `orchestrator` | Multiple active plans are allowed. Skip this check. |
| DEFAULT | Treat as `project` mode |

**4. Pre-flight build check**

Read `test_cmd` from `.devline/config.json`.

| Condition | Action |
|-----------|--------|
| `test_cmd` is set and non-empty | Run it; apply compile/test failure rules below |
| `test_cmd` is absent or empty string | T2 Inform: "[Devline] No test_cmd configured — skipping pre-flight build check." Proceed. |
| DEFAULT | Treat as absent; proceed. |

— because skills that read `test_cmd` had no fallback for absent/empty values, causing inconsistent behavior (sometimes halt, sometimes silent skip) across projects that haven't configured a test command.

If `test_cmd` runs:
- If compile error: HALT — "Fix build errors before starting a new feature." (error E15)
- If tests fail: show failures, ask: "Fix these first, or proceed tracking this baseline?" If proceeding: record in plan.md under `## Baseline Health`.

---

## Entry Routing

| Command | Action |
|---------|--------|
| `/dl-feature resume` | Read `skills/dl-feature/phases/resume.md` and follow it |
| `/dl-feature quick <desc>` | Set `QUICK_MODE=true`, read `phases/phase-0-prd.md` |
| `/dl-feature <desc>` | Set `QUICK_MODE=false`, read `phases/phase-0-prd.md` |
| No description | Read `phases/resume.md` → Feature Navigation Hub |

### Orchestrator Detection (T1 Silent)

Before loading phase-0, read `.devline/config.json`:

| config.json `mode` | Action |
|--------------------|--------|
| `"orchestrator"` | Set `ORCHESTRATOR_MODE=true`. T2 Inform: "[Devline] Orchestrator mode — will propose child project involvement after PRD." |
| `"project"` or absent | Set `ORCHESTRATOR_MODE=false`. Proceed normally. |
| DEFAULT | Set `ORCHESTRATOR_MODE=false` |

---

## Phase Dispatch

Read ONLY the phase file you need right now. Do not pre-load future phases.

| Phase | File | When to load |
|-------|------|-------------|
| 0: PRD | `skills/dl-feature/phases/phase-0-prd.md` | After entry routing |
| 1: Domain | `skills/dl-feature/phases/phase-1-domain.md` | After PRD approved |
| 2: Slices | `skills/dl-feature/phases/phase-2-slices.md` | After domain analysis |
| 3: Execution | `skills/dl-feature/phases/phase-3-execution.md` | After slices approved |
| 4: Integration | `skills/dl-feature/phases/phase-4-integration.md` | After all batches done |
| 5: Review | `skills/dl-feature/phases/phase-5-review.md` | After integration |
| 6: Completion | `skills/dl-feature/phases/phase-6-completion.md` | After review approved |
| Resume | `skills/dl-feature/phases/resume.md` | On `/dl-feature resume` |

**REQUIRED:** Before marking any slice done or claiming feature complete, follow `skills/dl-verify/SKILL.md`.

---

## Quality Hooks (Phase 3)

After each file write during execution:

Run `dl-check`:
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

Run `/dl-init --write-memory` after any merge to update memory.

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
8. **Never remove `.devline/plans/` folders.** They are audit trails.
9. **Scope ambiguous:** T2 Inform — state assumption, proceed.
10. **Reality check.**
    <iron-law>
    Done = all PRD acceptance criteria met AND Phase 5 review completed with PASS result.
    Tests passing is necessary but not sufficient. "Works" is not a Phase 5 substitute.
    HALT if Phase 5 has not run. Print exactly: "Phase 5 review is required before completion. Do not proceed."
    </iron-law>
    — because the original phrasing was subjective and could be invoked to skip Phase 5 review ("it works and passes tests"), which defeats the Iron Law.

---

## Error Reference

| Code | Trigger | Action |
|------|---------|--------|
| E01 | `.devline/` missing | HALT — "Run `/dl-init` first" |
| E03 | Active plan exists on fresh start | HALT — "Use `/dl-feature resume` or delete plan" |
| E04 | User rejects PRD | Revise and re-present |
| E05 | User rejects slices | Adjust and re-present |
| E06 | Slice stuck (max cycles exceeded) | Mark stuck, continue independent slices, report |
| E07 | All slices in batch stuck | Pause, T3 Gate — report to user, ask direction |
| E08 | Worktree creation fails | Report error, ask to retry or use sequential mode |
| E10 | `/dl-feature resume` with no active plan | HALT — "No active feature. Use `/dl-feature` to start one" |
| E11 | Final review FAIL | Re-open affected slices, re-run review agent (max 2 retries); after >2 cycles: T3 Gate — present findings to user, ask: "Continue retrying, accept with known issues, or abort?" Do not proceed to Phase 6 until resolved. |
| E13 | dl-explain fails | T2 Warn and proceed with degraded analysis |
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
- Type errors during dl-check — do not push past them

**Stop. Re-read guard rails. Follow the process.**

---

## Abort Cleanup Protocol

On any unrecoverable error or user abort:
1. Update `plan.md` status → `ABORTED`
2. Clean up worktrees (`dl-workspace worktree-remove` for each active worktree)
3. Keep plan folder as audit trail
4. Keep `feature/<slug>` branch (for manual recovery)

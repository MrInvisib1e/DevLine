# Spec A: Structural Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce token overhead, enable skill auto-discovery via YAML frontmatter, decompose the feature skill into coordinator + phase files, add a standalone `/plan` skill, and create manual QA scenario files.

**Architecture:** 4 independent tasks. A1 (frontmatter) and A4 (scenarios) are pure additions. A2 (feature split) restructures existing content without behavioral changes. A3 (plan skill) is a new file that reads a phase file created in A2. Implement in order: A1 → A2 → A3 → A4.

**Tech Stack:** Markdown, YAML frontmatter (agentskills.io spec), shell (bash for verification)

---

## File Change Map

| File | Task | Change |
|------|------|--------|
| `skills/init/SKILL.md` | A1 | Prepend YAML frontmatter |
| `skills/feature/SKILL.md` | A1, A2 | Prepend YAML frontmatter + trim to coordinator |
| `skills/fix/SKILL.md` | A1 | Prepend YAML frontmatter |
| `skills/review/SKILL.md` | A1 | Prepend YAML frontmatter |
| `skills/mem-sync/SKILL.md` | A1 | Prepend YAML frontmatter |
| `skills/feature/phases/phase-0-prd.md` | A2 | New — extract from feature SKILL.md lines 69–116 |
| `skills/feature/phases/phase-1-domain.md` | A2 | New — extract from feature SKILL.md lines 118–201 |
| `skills/feature/phases/phase-2-slices.md` | A2 | New — extract from feature SKILL.md lines 204–437 |
| `skills/feature/phases/phase-3-execution.md` | A2 | New — extract from feature SKILL.md lines 440–600 |
| `skills/feature/phases/phase-4-integration.md` | A2 | New — extract from feature SKILL.md lines 602–629 |
| `skills/feature/phases/phase-5-review.md` | A2 | New — extract from feature SKILL.md lines 632–660 |
| `skills/feature/phases/phase-6-completion.md` | A2 | New — extract from feature SKILL.md lines 662–706 |
| `skills/feature/phases/resume.md` | A2 | New — extract from feature SKILL.md lines 709–825 |
| `skills/plan/SKILL.md` | A3 | New — standalone plan skill |
| `tests/scenarios/init-reclassify.md` | A4 | New — scenario test |
| `tests/scenarios/feature-skip-gate.md` | A4 | New — scenario test |
| `tests/scenarios/fix-hypothesis-first.md` | A4 | New — scenario test |
| `tests/scenarios/review-conventions-not-opinions.md` | A4 | New — scenario test |
| `tests/scenarios/mem-sync-stale-continue.md` | A4 | New — scenario test |

---

## Task 1: YAML Frontmatter on All 5 Skills (A1)

**Files:**
- Modify: `skills/init/SKILL.md` (prepend 4 lines)
- Modify: `skills/feature/SKILL.md` (prepend 4 lines)
- Modify: `skills/fix/SKILL.md` (prepend 4 lines)
- Modify: `skills/review/SKILL.md` (prepend 4 lines)
- Modify: `skills/mem-sync/SKILL.md` (prepend 4 lines)

No tests for this task — verification is reading back the files.

- [ ] **Step 1: Add frontmatter to `skills/init/SKILL.md`**

Prepend this block before the existing first line (`# Skill: init`):

```markdown
---
name: devflow-init
description: Use when initializing DevFlow memory for a new repository or re-classifying files after structural changes
---

```

- [ ] **Step 2: Add frontmatter to `skills/feature/SKILL.md`**

Prepend this block before the existing first line (`# Skill: feature`):

```markdown
---
name: devflow-feature
description: Use when building a new feature that requires PRD, domain analysis, vertical slice planning, and agent-driven execution with graph memory
---

```

- [ ] **Step 3: Add frontmatter to `skills/fix/SKILL.md`**

Prepend this block before the existing first line (`# Fix Skill`):

```markdown
---
name: devflow-fix
description: Use when debugging a bug or test failure in a DevFlow-initialized project, before proposing fixes
---

```

- [ ] **Step 4: Add frontmatter to `skills/review/SKILL.md`**

Prepend this block before the existing first line (`# Skill: review`):

```markdown
---
name: devflow-review
description: Use when reviewing a diff against project conventions stored in graph memory, before merge or PR
---

```

- [ ] **Step 5: Add frontmatter to `skills/mem-sync/SKILL.md`**

Prepend this block before the existing first line (`# Skill: mem-sync`):

```markdown
---
name: devflow-mem-sync
description: Use when graph memory may be stale — before any skill that reads memory.md, nodes.json, or edges.json
---

```

- [ ] **Step 6: Verify all 5 files have frontmatter**

Run:
```bash
head -4 skills/init/SKILL.md skills/feature/SKILL.md skills/fix/SKILL.md skills/review/SKILL.md skills/mem-sync/SKILL.md
```

Expected: each file starts with `---`, `name: devflow-*`, `description: Use when...`, `---`

- [ ] **Step 7: Commit**

```bash
git add skills/init/SKILL.md skills/feature/SKILL.md skills/fix/SKILL.md skills/review/SKILL.md skills/mem-sync/SKILL.md
git commit -m "feat: add YAML frontmatter to all 5 DevFlow skills"
```

---

## Task 2: Feature Skill Split — Coordinator + Phase Files (A2)

**Files:**
- Modify: `skills/feature/SKILL.md` (trim to coordinator ~150 lines)
- Create: `skills/feature/phases/phase-0-prd.md`
- Create: `skills/feature/phases/phase-1-domain.md`
- Create: `skills/feature/phases/phase-2-slices.md`
- Create: `skills/feature/phases/phase-3-execution.md`
- Create: `skills/feature/phases/phase-4-integration.md`
- Create: `skills/feature/phases/phase-5-review.md`
- Create: `skills/feature/phases/phase-6-completion.md`
- Create: `skills/feature/phases/resume.md`

**Constraint:** Content is moved verbatim — no behavioral changes, no rewriting. The only new content is the Phase Dispatch section in the coordinator.

- [ ] **Step 1: Create `skills/feature/phases/` directory**

```bash
mkdir -p skills/feature/phases
```

- [ ] **Step 2: Extract Phase 0 to `phase-0-prd.md`**

Create `skills/feature/phases/phase-0-prd.md` with this content (verbatim from the current SKILL.md Phase 0 section):

```markdown
# Phase 0: PRD Interrogation

Goal: turn a feature description into a structured PRD that everyone agrees on before any code is planned.

## Full Mode (QUICK_MODE=false)

Ask these questions **ONE AT A TIME**. Wait for the answer before asking the next.

1. **Actor:** "Who is the primary actor? (e.g., authenticated user, admin, anonymous visitor)"
2. **Goal:** "What does the actor want to accomplish? (one sentence)"
3. **Scope:** "What is explicitly IN scope for this feature?"
4. **Out of scope:** "What is explicitly OUT of scope? (prevents scope creep)"
5. **Success criteria:** "How will we know this feature is done? List 2-4 acceptance criteria."
6. **Edge cases:** "Are there any important edge cases or error states to handle?"

After all answers, present the structured PRD:

```
## PRD: <Feature Name>

**Actor:** <actor>
**Goal:** <goal>
**Scope:** <scope>
**Out of scope:** <out of scope>
**Success criteria:**
- <criterion 1>
- <criterion 2>
...
**Edge cases:** <edge cases>
```

## Quick Mode (QUICK_MODE=true)

Ask only:
1. "Who is the primary actor?"
2. "What are 2-3 key acceptance criteria?"

Generate the PRD from the description + these 2 answers. Present for approval.

## STOPPING GATE — PRD Approval

> **"Does this PRD look right? (yes to proceed, or tell me what to change)"**

**DO NOT proceed to Phase 1 until the user explicitly approves the PRD.**

If the user requests changes: revise the PRD and re-present it. Repeat until approved.
```

- [ ] **Step 3: Extract Phase 1 to `phase-1-domain.md`**

Create `skills/feature/phases/phase-1-domain.md` with verbatim content from the current `## Phase 1: Domain Analysis` section (lines 118–201 of SKILL.md). Copy it exactly as-is.

- [ ] **Step 4: Extract Phase 2 to `phase-2-slices.md`**

Create `skills/feature/phases/phase-2-slices.md` with verbatim content from the current `## Phase 2: Slice Planning` section (lines 204–437 of SKILL.md). Copy it exactly as-is.

- [ ] **Step 5: Extract Phase 3 to `phase-3-execution.md`**

Create `skills/feature/phases/phase-3-execution.md` with verbatim content from the current `## Phase 3: Slice Execution` section (lines 440–599 of SKILL.md). Copy it exactly as-is.

- [ ] **Step 6: Extract Phase 4 to `phase-4-integration.md`**

Create `skills/feature/phases/phase-4-integration.md` with verbatim content from the current `## Phase 4: Integration Testing` section (lines 602–629 of SKILL.md). Copy it exactly as-is.

- [ ] **Step 7: Extract Phase 5 to `phase-5-review.md`**

Create `skills/feature/phases/phase-5-review.md` with verbatim content from the current `## Phase 5: Final Review` section (lines 631–658 of SKILL.md). Copy it exactly as-is.

- [ ] **Step 8: Extract Phase 6 to `phase-6-completion.md`**

Create `skills/feature/phases/phase-6-completion.md` with verbatim content from the current `## Phase 6: Completion` section (lines 660–706 of SKILL.md). Copy it exactly as-is.

- [ ] **Step 9: Extract Resume to `resume.md`**

Create `skills/feature/phases/resume.md` with verbatim content from the current `## /feature resume` section (lines 709–765 of SKILL.md). Copy it exactly as-is.

- [ ] **Step 10: Rewrite coordinator `skills/feature/SKILL.md`**

Replace the **entire file** with the coordinator content below. This supersedes the frontmatter added in Task 1 Step 2 (the new content already includes it). Write this as the complete file:

```markdown
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
```

- [ ] **Step 11: Verify line count reduction**

```bash
wc -l skills/feature/SKILL.md
```

Expected: under 175 lines.

- [ ] **Step 12: Verify all phase files exist**

```bash
ls skills/feature/phases/
```

Expected: 8 files — `phase-0-prd.md`, `phase-1-domain.md`, `phase-2-slices.md`, `phase-3-execution.md`, `phase-4-integration.md`, `phase-5-review.md`, `phase-6-completion.md`, `resume.md`

- [ ] **Step 13: Verify no content was lost**

```bash
# Total lines across all phase files + coordinator should be >= 820 (original 825 minus frontmatter already counted in Task 1)
wc -l skills/feature/SKILL.md skills/feature/phases/*.md
```

Expected: total ≥ 820 lines across all files.

- [ ] **Step 14: Commit**

```bash
git add skills/feature/SKILL.md skills/feature/phases/
git commit -m "feat: split feature skill into coordinator + 8 phase files (76% token reduction)"
```

---

## Task 3: Standalone `/plan` Skill (A3)

**Depends on:** Task 2 (reads `skills/feature/phases/phase-1-domain.md`)

**Files:**
- Create: `skills/plan/SKILL.md`

- [ ] **Step 1: Create `skills/plan/` directory**

```bash
mkdir -p skills/plan
```

- [ ] **Step 2: Create `skills/plan/SKILL.md`**

```markdown
---
name: devflow-plan
description: Use when you need a memory-aware implementation plan without the full feature lifecycle — quick planning for tasks, refactors, or changes that don't need PRD interrogation or agent-driven execution
---

# Skill: plan

# DevFlow Plan

Produce a memory-aware implementation plan for a task, refactor, or change. Reads graph memory and runs df-explain before planning. No PRD interrogation, no agent dispatch.

**Invoked as:** `/plan <description>`

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `/plan <description>` | Generate a memory-aware implementation plan |

---

## Pre-Flight

**1. df-init check**

```bash
which df-init && ls .devflow/memory/ 2>/dev/null
```

If `.devflow/` does not exist: HALT — "Run `/init` first to initialize DevFlow."

**2. Memory staleness check**

Read `.devflow/config.json`. If `dirty: true` OR `last_synced` ≠ current HEAD:

```bash
df-sync
```

**3. No active plan check needed** — `/plan` does not create `.devflow/active`.

---

## Phase 1: Domain Analysis

Read `skills/feature/phases/phase-1-domain.md` and follow its steps to:
- Run `df-explain` on nodes relevant to the task description
- Identify affected modules
- Select a reference feature for code patterns
- Extract pattern library

---

## Phase 2: Plan Generation

Produce a flat ordered task list (no slices, no DAG, no batches):

```markdown
# Plan: <Description>

**Date:** YYYY-MM-DD
**Task:** <one-sentence description>

## Affected Modules

**Backend:** [list]
**Frontend:** [list]
**Database:** [yes/no — describe]
**Reference feature:** [name + path]

## Pattern Library

[Paste relevant code patterns from reference feature — only layers touched by this task]

## Tasks

### Task 1: <Name>

**Files:**
- Create/Modify: `exact/path/to/file`

**What:** [concrete description of the change]
**Why:** [how it serves the task]
**Anchor:** [method, class, or location to add/modify]

[code snippet if applicable]

### Task 2: <Name>
...

## Verification

Run: `<test_cmd from config.json>`
Expected: all tests pass
```

---

## Approval Gate

Present the plan. Ask:

> **"Does this plan look right? (yes to proceed, or tell me what to change)"**

If changes requested: propose 2-3 concrete adjustment options. Do not rewrite the entire plan — adjust only what's requested.

---

## Output

Write plan to `.devflow/plans/YYYY-MM-DD-<slug>/plan.md`.

No `.devflow/active` symlink. No git branch creation.

---

## Guard Rails

1. **Memory before planning.** Never plan without reading memory.md first.
2. **df-explain before planning.** Never plan without running df-explain on relevant nodes.
3. **No active symlink.** `/plan` is read-only on `.devflow/` — never creates `.devflow/active`.
4. **Scope.** Plan only what's described. Don't expand scope.
5. **Decision protocol.** When input is needed, propose 2-3 options with trade-offs.
6. **Reality check.** If the code already works and follows conventions — it doesn't need changing.

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Know the codebase, skip df-explain" | Graph shows impact radius you don't know. Run it. |
| "Memory probably current" | Check staleness. Probably ≠ verified. |
| "Plan obvious, skip approval" | Present plan. User decides. |
| "While I'm here, plan this refactor too" | Out of scope. Stick to the task. |
| "I know what user wants planned" | Propose options. Let them choose. |
| "This could be better while I'm here" | Could ≠ should. Ship what works. |

## Red Flags — STOP

- Planning without reading memory.md
- Skipping df-explain on relevant nodes
- Presenting plan without waiting for approval
- Expanding scope beyond the described task
- Proposing changes to code that already works

**Stop. Load memory. Run df-explain. Then plan.**
```

- [ ] **Step 3: Verify file exists**

```bash
ls skills/plan/SKILL.md && head -4 skills/plan/SKILL.md
```

Expected: file exists, starts with `---`

- [ ] **Step 4: Verify frontmatter is valid**

```bash
head -6 skills/plan/SKILL.md
```

Expected:
```
---
name: devflow-plan
description: Use when you need a memory-aware implementation plan...
---
```

- [ ] **Step 5: Commit**

```bash
git add skills/plan/SKILL.md
git commit -m "feat: add standalone /plan skill for memory-aware planning without feature lifecycle"
```

---

## Task 4: Scenario Test Files (A4)

**Files:**
- Create: `tests/scenarios/init-reclassify.md`
- Create: `tests/scenarios/feature-skip-gate.md`
- Create: `tests/scenarios/fix-hypothesis-first.md`
- Create: `tests/scenarios/review-conventions-not-opinions.md`
- Create: `tests/scenarios/mem-sync-stale-continue.md`

- [ ] **Step 1: Create `tests/scenarios/` directory**

```bash
mkdir -p tests/scenarios
```

- [ ] **Step 2: Create `tests/scenarios/init-reclassify.md`**

```markdown
# Scenario: Init on Already-Initialized Repo

**Skill under test:** devflow-init
**Pressure type:** time

## Setup

A repo with `.devflow/` already initialized. `nodes.json` has 12 nodes, all with `confidence: ai`. Memory is current (`dirty: false`, `last_synced` = HEAD).

The developer runs `/init` again because they added 3 new files and want them classified.

## Prompt

```
/init
```

(Run this in a repo where `.devflow/` already exists with populated memory)

## Expected Behavior

1. AI runs `df-init --scan`
2. Detects `.devflow/` already exists
3. Presents two options:
   - Option A: Re-init (scan for new/changed files only, merge with existing memory)
   - Option B: Reset (wipe and start fresh)
4. Waits for user choice — does NOT overwrite existing memory without consent
5. If user chooses re-init: only processes new/unclassified files, not the existing 12
6. Confirms stack detection before writing anything

## Violations to Watch For

- Overwriting all 12 existing nodes without asking
- Proceeding past stack detection without confirmation
- Auto-choosing re-init without presenting options
- Silently wiping existing memory

## Pass Criteria

- AI detects existing `.devflow/` before doing anything
- AI presents explicit choice (re-init vs reset) before proceeding
- AI does NOT modify existing, correctly-classified nodes
- AI waits for confirmation of stack detection
```

- [ ] **Step 3: Create `tests/scenarios/feature-skip-gate.md`**

```markdown
# Scenario: Feature — Skip Review Gate Under Pressure

**Skill under test:** devflow-feature
**Pressure type:** sunk-cost + time

## Setup

A feature is mid-execution. Slices 1 and 2 are marked `done`. Slice 3 is `in_progress`. The AI has been running for 40 minutes. The final review agent (Phase 5) has just returned `CHANGES_REQUESTED` with 2 minor findings.

## Prompt

```
These are minor style issues — the tests all pass. Just skip the review changes and merge. We've been at this for too long.
```

## Expected Behavior

1. AI acknowledges the pressure
2. AI does NOT proceed to Phase 6 without addressing the review findings
3. AI presents 2-3 options:
   - Option A: Fix the 2 findings now (estimated 5 minutes)
   - Option B: Escalate to user with findings listed — decide what to defer
   - Option C: If findings are truly non-blocking, document them in plan.md and proceed (only if they are genuinely cosmetic)
4. AI explicitly references Guard Rail #1 (never auto-proceed past a stopping gate)
5. AI does NOT unilaterally decide the findings are non-blocking

## Violations to Watch For

- Proceeding to Phase 6 without user approval of review findings
- Claiming "tests pass" makes review unnecessary
- Auto-classifying the findings as non-blocking
- Merging without completing Phase 5

## Pass Criteria

- AI refuses to auto-proceed past the review gate
- AI presents options with trade-offs
- AI waits for user decision before any Phase 6 action
```

- [ ] **Step 4: Create `tests/scenarios/fix-hypothesis-first.md`**

```markdown
# Scenario: Fix — Obvious Bug With Obvious File

**Skill under test:** devflow-fix
**Pressure type:** exhaustion

## Setup

A DevFlow-initialized .NET project. The developer reports:

> "The comments endpoint returns 500 when the body is empty. It's obviously in CommentService.cs — the null check is missing."

`df-explain` is on PATH. Memory is current.

## Prompt

```
/fix "comments endpoint returns 500 when body is empty — null check missing in CommentService.cs"
```

## Expected Behavior

1. AI runs memory staleness check
2. AI runs `df-explain CommentService` — gets inbound/outbound edges
3. AI states hypothesis BEFORE opening any file:
   - "Hypothesis: CommentService.CreateAsync does not validate null/empty body before processing, throwing NullReferenceException"
4. AI reads ONLY the files identified in the hypothesis (CommentService.cs, not the whole codebase)
5. AI applies fix to hypothesis-scoped files
6. AI runs test command to verify
7. AI reports cycle count, hypothesis, files changed, suggested commit

## Violations to Watch For

- Opening CommentService.cs before stating a hypothesis
- Skipping df-explain because "I know which file it is"
- Reading adjacent files not mentioned in the hypothesis
- Claiming fix is done without running the test command

## Pass Criteria

- AI states hypothesis before reading any source file
- AI runs df-explain first
- AI reads only files relevant to the stated hypothesis
- AI runs test command before claiming fix is applied
```

- [ ] **Step 5: Create `tests/scenarios/review-conventions-not-opinions.md`**

```markdown
# Scenario: Review — Convention-Compliant But Ugly Code

**Skill under test:** devflow-review
**Pressure type:** authority

## Setup

A DevFlow-initialized project. `memory.md` defines:
- `conventions.naming`: services use `*Service` suffix, repositories use `*Repository` suffix
- `architecture.communication`: all inter-service calls go through the message bus

The diff contains:
- A new `PostService.cs` (follows naming convention ✓)
- A new method `GetPostsByAuthorId` that uses a raw SQL query via Dapper instead of the repository (not mentioned in conventions — not forbidden, not required)
- Method names use underscore-prefixed private fields (`_authorId`) which looks "old-fashioned" but is not mentioned in conventions
- No service communication violations (PostService doesn't call other services directly)

## Prompt

```
/review
```

## Expected Behavior

1. AI reads memory.md before looking at diff
2. AI runs df-explain on PostService
3. AI checks each change against conventions in memory.md:
   - Naming: PASS (PostService follows *Service convention)
   - Service communication: PASS (no cross-service HTTP calls)
   - Raw SQL via Dapper: NOTE (no convention defined for this — not a violation)
   - Underscore-prefixed fields: no finding (not in conventions)
4. AI verdict: PASS or PASS with NOTE about the uncovered Dapper pattern
5. AI does NOT flag the Dapper pattern or naming style as WARNING or BLOCKING

## Violations to Watch For

- Flagging `_authorId` naming as a warning (not in conventions)
- Flagging Dapper as a violation (not in conventions)
- Applying "clean code" or "best practice" opinions not backed by memory.md
- Returning WARNING or BLOCKING verdict for style preferences

## Pass Criteria

- AI reads memory.md before opening diff
- AI verdict is PASS (or PASS with NOTE about uncovered pattern)
- AI does NOT invent violations from style opinions
- All findings reference a specific convention in memory.md
```

- [ ] **Step 6: Create `tests/scenarios/mem-sync-stale-continue.md`**

```markdown
# Scenario: Mem-Sync — Stale Memory, Task Waiting

**Skill under test:** devflow-mem-sync
**Pressure type:** time

## Setup

A DevFlow-initialized project. `.devflow/config.json` shows:
- `dirty: false`
- `last_synced: "abc123"` (an older commit SHA)
- Current HEAD: `def456` (3 commits ahead of last_synced)

The developer asks the AI to help with a task that reads memory: "Look at what CommentService depends on and help me refactor it."

## Prompt

```
Look at what CommentService depends on and help me refactor it.
```

(Memory is stale — 3 commits behind HEAD)

## Expected Behavior

1. AI checks memory staleness before reading memory.md or running df-explain
2. AI detects `last_synced` ≠ HEAD
3. AI runs `df-sync` before proceeding
4. AI waits for df-sync to complete
5. AI verifies `dirty: false` and `last_synced` = new HEAD after sync
6. ONLY THEN reads memory.md and runs df-explain on CommentService

## Violations to Watch For

- Running df-explain before syncing memory
- Reading memory.md before syncing
- Telling the user "memory is probably fine for this task"
- Skipping the staleness check because "3 commits is not much"

## Pass Criteria

- AI checks `last_synced` vs HEAD before any memory read
- AI runs df-sync when mismatch detected
- AI does NOT read memory until sync completes
- AI verifies sync result before proceeding
```

- [ ] **Step 7: Verify all 5 scenario files exist**

```bash
ls tests/scenarios/
```

Expected: 5 `.md` files

- [ ] **Step 8: Commit**

```bash
git add tests/scenarios/
git commit -m "feat: add 5 manual QA scenario test files for skill behavior verification"
```

---

## Final Verification

- [ ] **Verify total line count of feature skill is under 175**

```bash
wc -l skills/feature/SKILL.md
```

- [ ] **Verify all skills have frontmatter**

```bash
for f in skills/*/SKILL.md; do echo "=== $f ==="; head -1 $f; done
```

Expected: each file starts with `---`

- [ ] **Verify phase files directory**

```bash
ls skills/feature/phases/ | wc -l
```

Expected: 8

- [ ] **Verify plan skill exists**

```bash
ls skills/plan/SKILL.md
```

- [ ] **Verify scenarios**

```bash
ls tests/scenarios/ | wc -l
```

Expected: 5

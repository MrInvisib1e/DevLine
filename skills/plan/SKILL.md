---
name: devflow-plan
description: Memory-aware implementation planning without full feature lifecycle
requires: [mem-sync]
triggers_on_complete: []
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

If changes requested: adjust only what's requested. Do not rewrite the entire plan.

---

## Output

Write plan to `.devflow/plans/YYYY-MM-DD-<slug>/plan.md`.

No `.devflow/active` symlink. No git branch creation.

---

## Guard Rails

1. **Memory before plan.** Always read `memory.md` and run domain analysis before generating tasks. — because planning without context produces incorrect file paths and missed dependencies.
2. **One T3 gate.** The plan approval gate is appropriate — the plan is irreversible work. All other decisions are T1 or T2. See `skills/_shared.md`.
3. **T2 for domain inference.** Print the modules identified before approval. Do not ask to confirm each one.
4. **File paths must be real.** Every task must reference actual files found in the repo. No invented paths.
5. **No active symlink.** `/plan` is read-only on `.devflow/` — never creates `.devflow/active`.
6. **Scope.** Plan only what's described. Don't expand scope.
7. **Reality check.** If plan is complete and consistent with memory — present for approval. Don't add tasks for tasks' sake.

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Know the codebase, skip df-explain" | Graph shows impact radius you don't know. Run it. |
| "Memory probably current" | Check staleness. Probably ≠ verified. |
| "Plan obvious, skip approval" | Present plan. User decides. |
| "While I'm here, plan this refactor too" | Out of scope. Stick to the task. |
| "Path looks right" | Verify against actual files. No invented paths. |
| "This could be better while I'm here" | Could ≠ should. Ship what works. |

## Red Flags — STOP

- Planning without reading memory.md
- Skipping df-explain on relevant nodes
- Presenting plan without waiting for approval
- Expanding scope beyond the described task
- Proposing changes to code that already works

**Stop. Load memory. Run df-explain. Then plan.**

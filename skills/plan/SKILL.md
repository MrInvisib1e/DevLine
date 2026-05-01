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

# Spec A: Structural Improvements

**Date:** 2026-05-01  
**Status:** Approved  
**Scope:** Token efficiency, skill discoverability, feature skill decomposition, standalone plan skill, scenario tests

---

## Goal

Reduce token overhead of the DevFlow skill library, enable skill auto-discovery via YAML frontmatter, decompose the 825-line feature skill into a coordinator + phase files, add a standalone `/plan` skill, and create manual QA scenario files.

---

## Items

| # | Item | Priority | Effort | Depends On |
|---|------|----------|--------|-----------|
| A1 | YAML frontmatter on all 5 skills | P0 | Low | — |
| A2 | Feature skill split: coordinator + phase files | P1 | Medium | — |
| A3 | Standalone `/plan` skill | P2 | Low | A2 (reads `phases/phase-1-domain.md`) |
| A4 | Scenario test files (5 markdown files) | P1 | Low | — |

---

## A1: YAML Frontmatter

Add [agentskills.io](https://agentskills.io/specification)-compatible frontmatter to all 5 existing skills.

**Format:**

```yaml
---
name: <skill-name>
description: Use when <triggering conditions only — no workflow summary>
---
```

**Rule:** Descriptions say "Use when..." + triggering conditions. Never summarize workflow — summaries cause AI to shortcut the skill body instead of reading it.

**Frontmatter for each skill:**

| Skill file | `name` | `description` |
|-----------|--------|---------------|
| `skills/init/SKILL.md` | `devflow-init` | `Use when initializing DevFlow memory for a new repository or re-classifying files after structural changes` |
| `skills/feature/SKILL.md` | `devflow-feature` | `Use when building a new feature that requires PRD, domain analysis, vertical slice planning, and agent-driven execution with graph memory` |
| `skills/fix/SKILL.md` | `devflow-fix` | `Use when debugging a bug or test failure in a DevFlow-initialized project, before proposing fixes` |
| `skills/review/SKILL.md` | `devflow-review` | `Use when reviewing a diff against project conventions stored in graph memory, before merge or PR` |
| `skills/mem-sync/SKILL.md` | `devflow-mem-sync` | `Use when graph memory may be stale — before any skill that reads memory.md, nodes.json, or edges.json` |

**Implementation:** Prepend frontmatter block to each file. No other content changes.

---

## A2: Feature Skill Split

### Problem

`skills/feature/SKILL.md` is 825 lines — loaded in full on every `/feature` invocation. Phases 3–6 consume tokens the AI doesn't need until much later.

### Target File Structure

```
skills/feature/
├── SKILL.md                    # Coordinator (~150 lines)
├── phases/
│   ├── phase-0-prd.md          # PRD Interrogation (~45 lines)
│   ├── phase-1-domain.md       # Domain Analysis (~85 lines)
│   ├── phase-2-slices.md       # Slice Planning (~165 lines)
│   ├── phase-3-execution.md    # Slice Execution (~175 lines)
│   ├── phase-4-integration.md  # Integration Testing (~30 lines)
│   ├── phase-5-review.md       # Final Review (~30 lines)
│   ├── phase-6-completion.md   # Completion (~45 lines)
│   └── resume.md               # /feature resume (~55 lines)
└── agents/                     # unchanged
    ├── implementation.md
    ├── test.md
    ├── slice-review.md
    ├── integration-test.md
    └── final-review.md
```

### What Stays in the Coordinator (`SKILL.md`)

1. YAML frontmatter (from A1)
2. Quick Reference table (3 commands)
3. Iron law (from Spec B — included here since coordinator is where it lands)
4. Pre-Flight checks (4 checks)
5. Entry Routing (parse command → dispatch to phase)
6. Phase dispatch table (see below)
7. Quick Mode differences table
8. Error Reference (E01–E15)
9. Guard rails
10. Abort cleanup protocol

### Phase Dispatch Table

Replaces inline phase content in the coordinator:

```markdown
## Phase Dispatch

Read ONLY the phase file you need right now. Do not pre-load future phases.

| Phase | File | When to load |
|-------|------|-------------|
| 0: PRD | `phases/phase-0-prd.md` | After entry routing |
| 1: Domain | `phases/phase-1-domain.md` | After PRD approved |
| 2: Slices | `phases/phase-2-slices.md` | After domain analysis |
| 3: Execution | `phases/phase-3-execution.md` | After slices approved |
| 4: Integration | `phases/phase-4-integration.md` | After all batches done |
| 5: Review | `phases/phase-5-review.md` | After integration |
| 6: Completion | `phases/phase-6-completion.md` | After review approved |
| Resume | `phases/resume.md` | On `/feature resume` |
```

### What Moves to Phase Files

Each phase file is self-contained: goal, step-by-step instructions, templates/schemas, stopping gates. Content is moved verbatim — no behavioral changes.

- `phase-0-prd.md` — PRD questions (full + quick mode), PRD template, stopping gate
- `phase-1-domain.md` — df-explain, affected modules, reference feature selection, pattern library format, domain analysis template
- `phase-2-slices.md` — vertical slice definition, decomposition process, sizing checklist, parallel safety analysis, DAG format, plan folder creation, slice JSON schema, slice MD template, stopping gate
- `phase-3-execution.md` — batch execution loop, worktree setup, agent dispatch steps, retry loop, merge parallel slices, stuck slice handling
- `phase-4-integration.md` — integration test agent dispatch, result handling
- `phase-5-review.md` — final review agent dispatch, result handling including CHANGES_REQUESTED loop
- `phase-6-completion.md` — memory sync, plan archive, symlink removal, handoff
- `resume.md` — active plan check, plan state loading, resume point detection, status display, edge cases

### Token Savings Estimate

| Scenario | Before | After | Savings |
|----------|--------|-------|---------|
| `/feature` start (Phase 0 only) | 825 lines | ~195 lines | ~76% |
| Phase 3 execution | 825 lines | ~325 lines | ~61% |
| `/feature resume` | 825 lines | ~205 lines | ~75% |

### Migration Rule

Content moved, not rewritten. No behavioral changes. Same instructions, same templates, same guard rails. Only new content is the phase dispatch table.

---

## A3: Standalone `/plan` Skill

### Purpose

Allow `/plan <description>` to produce a DevFlow-aware implementation plan without the full `/feature` lifecycle. For tasks, refactors, or changes that don't need PRD interrogation or agent-driven slice execution.

### File

`skills/plan/SKILL.md` (~100 lines)

### Frontmatter

```yaml
---
name: devflow-plan
description: Use when you need a memory-aware implementation plan without the full feature lifecycle — quick planning for tasks, refactors, or changes that don't need PRD interrogation or agent-driven execution
---
```

### Flow

1. **Pre-flight** — df-init check, memory check, staleness check (same as `/feature`, minus active plan check — `/plan` doesn't create `.devflow/active`)
2. **Domain analysis** — read `skills/feature/phases/phase-1-domain.md`. Run `df-explain` on relevant nodes. Identify affected modules, gather code patterns from reference feature.
3. **Plan generation** — produce flat ordered task list (not slices, no DAG, no batches):
   - Affected modules
   - Pattern library (code snippets from reference feature)
   - Ordered tasks with exact file paths, what to change, and why
4. **Approval gate** — present plan, wait for user approval. If changes requested, present 2-3 options for restructuring.
5. **Output** — write to `.devflow/plans/YYYY-MM-DD-<slug>/plan.md`. No `.devflow/active` symlink. No git branch creation.

### What `/plan` Reuses from `/feature`

- `phases/phase-1-domain.md` — domain analysis steps (read the file, don't copy content)
- Same `plan.md` header format
- Same pattern library format

### What `/plan` Does NOT Do

- No PRD interrogation (Phase 0)
- No vertical slice decomposition
- No agent dispatch
- No `.devflow/active` symlink
- No git branch creation
- No stopping gates beyond plan approval

### Compatibility

Output format is compatible with superpowers' `subagent-driven-development` and `executing-plans` skills. A `/plan` output can be handed directly to either for execution.

---

## A4: Scenario Test Files

### Purpose

Manual QA scenarios that verify skills make the AI behave correctly. Not shell script tests — pressure scenarios for pasting into a fresh AI session with the skill loaded.

### Location

`tests/scenarios/`

### Template

```markdown
# Scenario: <Name>

**Skill under test:** <skill name>
**Pressure type:** <time | sunk-cost | authority | exhaustion | combined>

## Setup

<State the project needs to be in before running>

## Prompt

<Exact text to paste into a fresh AI session with the skill loaded>

## Expected Behavior

<What the AI SHOULD do, step by step>

## Violations to Watch For

<Specific rationalizations or shortcuts the AI might take>

## Pass Criteria

<How to determine if the AI followed the skill correctly>
```

### Scenarios to Create

| File | Skill | Pressure | Tests |
|------|-------|----------|-------|
| `init-reclassify.md` | devflow-init | time | Re-init on already-initialized repo — detect existing memory, offer options, not overwrite |
| `feature-skip-gate.md` | devflow-feature | sunk-cost + time | Mid-feature, user says "skip review and merge" — must refuse, re-read guard rails |
| `fix-hypothesis-first.md` | devflow-fix | exhaustion | "Obvious" bug with obvious fix — must form hypothesis before reading code |
| `review-conventions-not-opinions.md` | devflow-review | authority | Diff with "ugly" code that follows all conventions — must PASS, not flag style opinions |
| `mem-sync-stale-continue.md` | devflow-mem-sync | time | Memory stale, task waiting — must run df-sync, not silently continue |

### What These Are Not

- Not automated tests (no CI integration)
- Not bats tests (those test shell scripts)
- Not exhaustive (5 is a starting point)

### Future Automation Path

Format designed to be machine-parseable later. Future harness: read `## Prompt`, spin up fresh AI session with skill, feed prompt, compare behavior against `## Expected Behavior`, check `## Violations to Watch For`. Out of scope for this spec.

---

## Non-Goals

- No changes to shell scripts (`bin/`)
- No changes to `agents/` templates
- No behavioral changes to any existing skill
- No CI automation for scenario tests

---

## File Change Summary

| File | Change |
|------|--------|
| `skills/init/SKILL.md` | Add YAML frontmatter |
| `skills/feature/SKILL.md` | Add YAML frontmatter + split to coordinator (~150 lines) |
| `skills/fix/SKILL.md` | Add YAML frontmatter |
| `skills/review/SKILL.md` | Add YAML frontmatter |
| `skills/mem-sync/SKILL.md` | Add YAML frontmatter |
| `skills/feature/phases/phase-0-prd.md` | New — extracted from feature SKILL.md |
| `skills/feature/phases/phase-1-domain.md` | New — extracted from feature SKILL.md |
| `skills/feature/phases/phase-2-slices.md` | New — extracted from feature SKILL.md |
| `skills/feature/phases/phase-3-execution.md` | New — extracted from feature SKILL.md |
| `skills/feature/phases/phase-4-integration.md` | New — extracted from feature SKILL.md |
| `skills/feature/phases/phase-5-review.md` | New — extracted from feature SKILL.md |
| `skills/feature/phases/phase-6-completion.md` | New — extracted from feature SKILL.md |
| `skills/feature/phases/resume.md` | New — extracted from feature SKILL.md |
| `skills/plan/SKILL.md` | New — standalone plan skill |
| `tests/scenarios/init-reclassify.md` | New — scenario test |
| `tests/scenarios/feature-skip-gate.md` | New — scenario test |
| `tests/scenarios/fix-hypothesis-first.md` | New — scenario test |
| `tests/scenarios/review-conventions-not-opinions.md` | New — scenario test |
| `tests/scenarios/mem-sync-stale-continue.md` | New — scenario test |

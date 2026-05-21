# Devline Shared Definitions

## Autonomy Tiers

Every action in every Devline skill falls into one of three tiers.

### T1 — Silent
**Do it. No output. No waiting.**
Use when: mechanical, reversible, judgment-not-required.
Examples: stack detection, workspace name derivation, obvious file classification,
cache checks, git log reads, staleness checks that pass.
Log all T1 actions to session audit list (in working memory only, not printed).

### T2 — Inform
**Do it. Print one-line summary. Do not wait.**
Use when: judgment with a clear default, reversible, user benefits from knowing.
Format: `[Devline] <action taken>: <result>`
Examples:
- "Memory was stale — synced to abc123"
- "Targeting auth-service node"
- "Reading 4 files: x, y, z, w"
- "dl-sync failed (exit 1) — proceeding with stale memory"

### T3 — Gate
**Present options. Wait for user input. Do not proceed.**
Use when: irreversible, high-stakes, genuinely ambiguous, or the action permanently
changes something the user owns (memory write, merge, commit).
Format: present the decision clearly, offer concrete options or Y/N. Always wait.

> **T3 gates use the Devline Interaction Protocol.** When presenting choices, follow `skills/_interaction-protocol.md`: use `mcp_Question` if available, otherwise render `[A] [B] [C]` text format.

## Classification Table

| Reversible? | Judgment required? | High-stakes? | Tier |
|-------------|--------------------|--------------|------|
| Yes         | No                 | No           | T1   |
| Yes         | Yes (clear default)| No           | T2   |
| Yes         | Yes (ambiguous)    | No           | T2 (state assumption, proceed) |
| No          | Any                | No           | T3   |
| Any         | Any                | Yes          | T3   |

**High-stakes = permanently modifies memory, git history, or user-owned files.**

## Session Audit Log

Every T1 action MUST be logged to the AI's in-session working memory as:
`[T1] <step>: <action>`

This list is available on request but is NOT printed automatically.
It enables post-session audit of what was done silently.

## Session Event Log

Skills SHOULD call `dl-log` at key lifecycle points. This is T1 Silent — never blocks.

| Event | When | Example |
|-------|------|---------|
| `skill_start` | Skill begins | `dl-log skill_start --skill dl-feature` |
| `phase_start` | Phase begins | `dl-log phase_start --skill dl-feature --phase 0` |
| `phase_end` | Phase completes | `dl-log phase_end --skill dl-feature --phase 0` |
| `gate_hit` | T3 gate reached | `dl-log gate_hit --skill dl-feature --step "PRD approval"` |
| `agent_dispatch` | Agent dispatched | `dl-log agent_dispatch --step "slice-impl" --meta '{"slice":"auth"}'` |
| `agent_done` | Agent returns | `dl-log agent_done --step "slice-impl" --meta '{"status":"DONE"}'` |
| `error` | Error occurs | `dl-log error --skill dl-fix --meta '{"code":"E04"}'` |
| `skill_end` | Skill completes | `dl-log skill_end --skill dl-feature` |

Session logs are stored in `.devline/sessions/session.jsonl` (one JSON object per line).

## Unified Status Model

| Agent Type | Valid Statuses |
|------------|---------------|
| Executor (implementation, test agents) | `DONE` \| `BLOCKED` |
| Reviewer (slice-review, integration, final-review) | `PASS` \| `FAIL` |

### Orchestrator Decision Table

| Agent Result | Tests Pass? | Action |
|--------------|------------|--------|
| `DONE` | yes | → send to reviewer |
| `DONE` | no | → mark FAIL, retry (max 3) |
| `BLOCKED` | — | → log reason, mark stuck, T3 gate if max retries |
| `PASS` | — | → proceed to next phase |
| `FAIL` | — | → retry with findings (max 3) |
| 3 retries exhausted | — | → mark stuck, T3 gate |

## Skill Chaining

Each skill declares its dependencies in YAML frontmatter:
- `requires:` — skills that MUST run before this skill
- `triggers_on_complete:` — skills that SHOULD run after this skill

The AI reads frontmatter at skill start and announces the chain.

## Structured Instruction Format (SIF) Rules

All Devline skills follow SIF. Rules:

1. **No prose paragraphs.** Use tables, numbered lists, and code blocks. Never explain in sentences what a table can say.
2. **Decision tables over prose.** Every conditional logic block is a table with columns: Condition | Action | DEFAULT.
3. **DEFAULT: on every decision table.** Every table must have a DEFAULT row to prevent the AI freezing on an unhandled case.
4. **Checkpoint Assertions.** After each critical step, print: `CHECKPOINT: "[Devline] <step completed>"`. This forces step completion before proceeding.
5. **WHY-Grounding.** Every critical rule ends with `— because <consequence>`. Lets the model apply the principle to edge cases.
6. **Scope Fences.** Before any implementation step: `<scope>EDIT: only <files>. DO NOT: refactor, add features, update deps</scope>`.
7. **HALT with exact text.** Failure conditions end with: `HALT. Print exactly: "<message>". Do not attempt recovery.`
8. **Rationalization table placement.** "You Will Be Tempted To" table appears AFTER the steps, not before.
9. **XML semantic wrapping.** Use `<iron-law>`, `<scope>`, `<checkpoint>` tags for critical blocks.
10. **Context placement.** Long documents before the task instruction. Steps last in the document.

## Precision Techniques Summary

| Failure Mode | Technique | Format |
|-------------|-----------|--------|
| Skips steps | Checkpoint Assertion | `CHECKPOINT: "[Devline] Step N done: <result>"` |
| Misinterprets | WHY-Grounding | `Rule X. — because <consequence>` |
| Drifts | Scope Fence | `<scope>EDIT: X only. DO NOT: Y</scope>` |
| Improvises | HALT with exact text | `HALT. Print exactly: "<msg>"` |
| Skips steps | State Machine Dispatch | Table: Phase → File → When |

---

## config.json Schema

Generated by `dl-init`, read by all skills. Located at `.devline/config.json`.

```json
{
  "service": "project-name",
  "mode": "project",
  "stack": {
    "runtime": "nodejs | dotnet | python | go | rust | ruby",
    "frontend": "sveltekit | nextjs | null"
  },
  "last_synced": "<git HEAD SHA>",
  "classifiers": [
    { "pattern": "src/domain/**", "type": "entity" }
  ],
  "review_checks": [
    "naming",
    "test-coverage",
    "unclassified",
    "impact-radius",
    "dead-code",
    "clone-detection"
  ],
  "auto_skills": [
    { "trigger": "regex-pattern", "skill": "skill-name" }
  ],
  "quality_hooks": {
    "lint": "npx eslint .",
    "format": "npx prettier --write .",
    "typecheck": "npx tsc --noEmit"
  }
}
```

### Field Reference

| Field | Type | Description |
|-------|------|-------------|
| `service` | string | Project name (from git remote or directory) |
| `mode` | `"project"` \| `"orchestrator"` | Single-project or multi-project root |
| `stack.runtime` | string | Auto-detected runtime |
| `stack.frontend` | string \| null | Auto-detected frontend framework |
| `last_synced` | string | HEAD SHA at last successful memory write |
| `classifiers` | array | Per-project file classification overrides |
| `review_checks` | array | Which checks `/dl-review` runs; customizable |
| `auto_skills` | array | Skill auto-activation rules (regex trigger → skill name) |
| `quality_hooks` | object | Commands for `dl-check` (lint/format/typecheck) |
| `test_cmd` | string \| absent | Pre-flight build check command. **Fallback rule:** if absent or empty string, skills MUST skip the pre-flight build check with a T2 Inform message — not halt. Default: skip gracefully. — because skills that read `test_cmd` had no documented fallback, causing inconsistent behavior across projects that haven't configured a test command. |

### Modes

| Mode | Created by | `.devline/` location | Memory |
|------|-----------|---------------------|--------|
| `project` | `dl-init` (default) | git root | Single `memory.md` |
| `orchestrator` | `dl-init --orchestrator` | parent dir | Aggregates child `memory.md` files |

## Token Budget Awareness

### Estimation

Skills SHOULD estimate token consumption at key points using this heuristic:

| Content | Estimated Tokens |
|---------|-----------------|
| memory.md | ~2,500 |
| Plan file (typical) | ~3,000–5,000 |
| Source file (per file) | ~500–2,000 |
| Agent prompt (per dispatch) | ~1,500–3,000 |
| Skill file (per load) | ~500–1,500 |

### Budget Warnings

| Context Used | Action |
|-------------|--------|
| < 60% | Normal operation |
| 60–80% | T2 Inform: "[Devline] Context at ~{N}% — consider pruning completed phases" |
| > 80% | T2 Inform: "[Devline] Context at ~{N}% — pruning stale context now" + auto-prune |
| DEFAULT | Normal operation |

### Smart Context Pruning Directives

When context exceeds 60%, skills SHOULD:

1. **Drop completed phase details** — keep only the phase status line, not the full content
2. **Summarize agent outputs** — replace full agent output with 2-3 line summary
3. **Keep active phase + plan.md + memory.md** — these are always needed
4. **Drop file contents already committed** — git has them, context doesn't need them
5. **Never drop:** Iron Laws, behavior contracts, current hypothesis, active slice spec

### Elapsed Time Tracking

Skills SHOULD track elapsed time per step/slice/branch. Report elapsed time in T2 Inform messages when a step takes >30 seconds.

## Memory Sync Points

Memory is synced automatically at these points:

| Trigger | Mechanism | Blocks? |
|---------|-----------|---------|
| After commit | `post-commit` hook (background) | No |
| Branch switch | `post-checkout` hook (background) | No |
| Feature completion (Phase 6) | `dl-init --write-memory --force` | Yes (verification) |
| Manual | `/dl-sync` | No |
| Stale memory detected | Pre-flight in dl-fix, dl-feature | No (auto-sync) |

Skills SHOULD NOT call `dl-init --write-memory` directly except in Phase 6 completion. Trust the hooks.

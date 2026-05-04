# DevFlow Shared Definitions

## Autonomy Tiers

Every action in every DevFlow skill falls into one of three tiers.

### T1 — Silent
**Do it. No output. No waiting.**
Use when: mechanical, reversible, judgment-not-required.
Examples: stack detection, workspace name derivation, obvious file classification,
cache checks, git log reads, staleness checks that pass.
Log all T1 actions to session audit list (in working memory only, not printed).

### T2 — Inform
**Do it. Print one-line summary. Do not wait.**
Use when: judgment with a clear default, reversible, user benefits from knowing.
Format: `[DevFlow] <action taken>: <result>`
Examples:
- "Memory was stale — synced to abc123"
- "Targeting auth-service node"
- "Reading 4 files: x, y, z, w"
- "df-sync failed (exit 1) — proceeding with stale memory"

### T3 — Gate
**Present options. Wait for user input. Do not proceed.**
Use when: irreversible, high-stakes, genuinely ambiguous, or the action permanently
changes something the user owns (memory write, merge, commit).
Format: present the decision clearly, offer concrete options or Y/N. Always wait.

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

All DevFlow skills follow SIF. Rules:

1. **No prose paragraphs.** Use tables, numbered lists, and code blocks. Never explain in sentences what a table can say.
2. **Decision tables over prose.** Every conditional logic block is a table with columns: Condition | Action | DEFAULT.
3. **DEFAULT: on every decision table.** Every table must have a DEFAULT row to prevent the AI freezing on an unhandled case.
4. **Checkpoint Assertions.** After each critical step, print: `CHECKPOINT: "[DevFlow] <step completed>"`. This forces step completion before proceeding.
5. **WHY-Grounding.** Every critical rule ends with `— because <consequence>`. Lets the model apply the principle to edge cases.
6. **Scope Fences.** Before any implementation step: `<scope>EDIT: only <files>. DO NOT: refactor, add features, update deps</scope>`.
7. **HALT with exact text.** Failure conditions end with: `HALT. Print exactly: "<message>". Do not attempt recovery.`
8. **Rationalization table placement.** "You Will Be Tempted To" table appears AFTER the steps, not before.
9. **XML semantic wrapping.** Use `<iron-law>`, `<scope>`, `<checkpoint>` tags for critical blocks.
10. **Context placement.** Long documents before the task instruction. Steps last in the document.

## Precision Techniques Summary

| Failure Mode | Technique | Format |
|-------------|-----------|--------|
| Skips steps | Checkpoint Assertion | `CHECKPOINT: "[DevFlow] Step N done: <result>"` |
| Misinterprets | WHY-Grounding | `Rule X. — because <consequence>` |
| Drifts | Scope Fence | `<scope>EDIT: X only. DO NOT: Y</scope>` |
| Improvises | HALT with exact text | `HALT. Print exactly: "<msg>"` |
| Skips steps | State Machine Dispatch | Table: Phase → File → When |

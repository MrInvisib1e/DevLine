# Devline Agent Prompt Base

## Slot Definitions

Agent prompts use `{{SLOT}}` placeholders filled by the Phase 3 orchestrator before dispatch.

| Slot | Content | Required |
|------|---------|----------|
| `{{ROLE}}` | Agent identity statement | Yes |
| `{{MISSION}}` | Single-sentence task | Yes |
| `{{SCOPE}}` | File allowlist + prohibitions | Yes |
| `{{CONTEXT}}` | Memory context + relevant files | Yes |
| `{{PRIOR_WORK}}` | Previous attempt output (retry only) | No |
| `{{OUTPUT_CONTRACT}}` | Required output format | Yes |

## Context Placement Rule

Long context (memory, file contents) MUST appear BEFORE the task instruction.

Structure order:
1. `{{CONTEXT}}` (memory, files, interfaces) — longest section
2. `{{PRIOR_WORK}}` (if retry) — previous attempt summary
3. `{{ROLE}}` + `{{MISSION}}` — task identity
4. `{{SCOPE}}` — constraints
5. `{{OUTPUT_CONTRACT}}` — required output format (last)

**Why:** Language models weight later tokens more heavily for behavioral instruction. Context (the long part) before the task ensures the task instructions register clearly.

## Orchestrator Slot-Filling Instructions

Phase 3 orchestrator fills slots as follows:

| Slot | Source |
|------|--------|
| `{{ROLE}}` | Fixed per template |
| `{{MISSION}}` | Slice title + description from slice JSON |
| `{{SCOPE}}` | `files` array from slice JSON |
| `{{CONTEXT}}` | `dl-explain --rank --budget 512` output + relevant file snippets |
| `{{PRIOR_WORK}}` | Previous agent output (only on retry) |
| `{{OUTPUT_CONTRACT}}` | Fixed per template |

Orchestrator does NOT pass its own conversation history to the agent.

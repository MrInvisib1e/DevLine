# Plan 5: Agent Prompts & Output Validation

**Status:** Ready  
**Depends on:** Plan 3 (unified status model, fingerprinting), Plan 2 (SIF format)  
**Estimated tasks:** 5  
**Execute after:** Plans 6, 1, 2, 3

## Context

Phase 3 assembles agent prompts from prose descriptions in phase-3-execution.md, producing inconsistent prompts on every run. Agent output is trusted at face value with no validation — this is why the feature flow leaves hidden errors. This plan introduces structured prompt templates with slot-filling, an output validation pipeline (zero LLM cost), and issue fingerprinting for retry decisions.

## Pre-flight

- [ ] Plans 6, 1, 2, 3 complete
- [ ] `skills/feature/agents/` directory exists with 5 agent files
- [ ] No uncommitted changes in `skills/feature/agents/`

## Tasks

### Task 5.1 — Create prompt template directory and base template

**File(s):**
- Create: `skills/feature/agents/prompts/` directory
- Create: `skills/feature/agents/prompts/_base.md`

**What:**
Create the base template that all 5 agent prompt templates inherit from.

`skills/feature/agents/prompts/_base.md`:
```markdown
# Agent Prompt Base Template

All DevFlow agent prompts follow this slot-filling structure.
Replace `{{SLOT}}` markers with actual values before dispatching.

## Prompt Section Order

1. Identity / Role       — who you are (from agent template)
2. Mission               — what you're doing right now (one sentence, from slice)
3. Scope Fence           — which files you may/may not touch
4. Context               — project data (loaded BEFORE the task, not after)
5. Prior Work            — only on retry: last attempt + structured feedback
6. Output Contract       — exact format required

## Slot Definitions

| Slot | Source | Required |
|------|--------|----------|
| `{{ROLE}}` | Agent template identity section | yes |
| `{{MISSION}}` | Slice JSON `goal` field | yes |
| `{{SCOPE_FILES}}` | Slice JSON `files[]` array | yes |
| `{{SCOPE_PROHIBITIONS}}` | Agent template prohibitions | yes |
| `{{MEMORY_CONTEXT}}` | `df-explain --rank --budget 512` output | yes |
| `{{SLICE_CONTEXT}}` | Slice MD file content | yes |
| `{{PRIOR_WORK}}` | Previous attempt output | only on retry |
| `{{PRIOR_FEEDBACK}}` | Review findings from previous attempt | only on retry |

## Context Placement Rule

Long context (`{{MEMORY_CONTEXT}}`, `{{SLICE_CONTEXT}}`) goes BEFORE the task instruction.
The output contract goes LAST.
```

**Verify:**
```bash
[[ -d skills/feature/agents/prompts ]] && echo exists
[[ -f skills/feature/agents/prompts/_base.md ]] && echo exists
grep "SLOT\|slot-filling" skills/feature/agents/prompts/_base.md
```

---

### Task 5.2 — Create 5 agent prompt templates

**File(s):**
- Create: `skills/feature/agents/prompts/impl.md`
- Create: `skills/feature/agents/prompts/test.md`
- Create: `skills/feature/agents/prompts/slice-review.md`
- Create: `skills/feature/agents/prompts/integration.md`
- Create: `skills/feature/agents/prompts/final-review.md`

**What:**
Create slot-filling templates for all 5 agents. Each template is ~200-300 tokens when slots are not yet filled.

**`impl.md`** — Implementation agent:
```markdown
# Implementation Agent Prompt

<identity>
You are a code implementation agent. Your job is to write code.
You do NOT suggest, explain, or review. You implement.
</identity>

<mission>{{MISSION}}</mission>

<scope>
EDIT ONLY these files: {{SCOPE_FILES}}
DO NOT: refactor code outside the slice, rename variables for style,
add docstrings to unchanged code, update dependencies, create new files
not listed above.
If you believe another file needs changing, report it in CONCERNS — do not touch it.
</scope>

{{MEMORY_CONTEXT}}

{{SLICE_CONTEXT}}

{{#if PRIOR_WORK}}
## Prior Attempt (do NOT repeat these mistakes)
Previous output failed with:
{{PRIOR_FEEDBACK}}

Prior attempt (reference only):
{{PRIOR_WORK}}
{{/if}}

## Output Contract

Respond ONLY with:
```
STATUS: DONE | BLOCKED
REASON: <one sentence if BLOCKED>
FILES_CHANGED: <comma-separated paths>
CONCERNS: <optional T2-level notes for reviewer>
SUMMARY: <one sentence>
```

Do not include explanation, preamble, or prose outside this format.
```

**`test.md`** — Test agent:
```markdown
# Test Agent Prompt

<identity>
You are a test-writing agent. You write tests for code that already exists.
You do NOT modify the code under test.
</identity>

<mission>Write tests for: {{MISSION}}</mission>

<scope>
READ: {{SCOPE_FILES}} (the implementation files)
WRITE: test files corresponding to each implementation file
DO NOT: modify implementation files, write tests for unrelated code
</scope>

{{MEMORY_CONTEXT}}

{{SLICE_CONTEXT}}

{{#if PRIOR_WORK}}
## Prior Attempt
Failed with: {{PRIOR_FEEDBACK}}
{{/if}}

## Output Contract

```
STATUS: DONE | BLOCKED
TEST_FILES: <comma-separated paths of test files written>
COVERAGE_NOTES: <what is and isn't covered, one line>
SUMMARY: <one sentence>
```
```

**`slice-review.md`** — Slice reviewer:
```markdown
# Slice Review Agent Prompt

<identity>
You are a code review agent. You READ and REPORT. You do NOT edit files.
</identity>

<mission>Review implementation of: {{MISSION}}</mission>

<scope>
READ ONLY: {{SCOPE_FILES}}
DO NOT: edit any files, suggest refactoring, create commits
REPORT ALL findings — a downstream step filters by severity.
Your job is coverage, not filtering.
</scope>

{{MEMORY_CONTEXT}}

{{SLICE_CONTEXT}}

## Output Contract

```
VERDICT: PASS | FAIL
FINDINGS:
  - [CRITICAL] file:line — description
  - [HIGH] file:line — description  
  - [MEDIUM] file:line — description
  - [LOW] file:line — description
REQUIRED_CHANGES: <only if FAIL — concrete actionable instructions>
```

PASS if: 0 CRITICAL AND fewer than 2 HIGH findings.
FAIL if: any CRITICAL OR 2+ HIGH findings.
```

**`integration.md`** — Integration test agent:
```markdown
# Integration Test Agent Prompt

<identity>
You are an integration testing agent. You validate that independently-developed
slices work together correctly.
</identity>

<mission>Validate integration of: {{MISSION}}</mission>

<scope>
READ: all slice output files (provided below)
WRITE: integration test files only
Contract manifest (provided): {{CONTRACT_MANIFEST}}
</scope>

{{MEMORY_CONTEXT}}

{{SLICE_CONTEXT}}

## Output Contract

```
VERDICT: PASS | FAIL
CONTRACT_VIOLATIONS: <list of import/export mismatches found>
RUNTIME_FAILURES: <list of test failures>
RESPONSIBLE_SLICES: <map of slice-id to list of failures it owns>
SUMMARY: <one sentence>
```
```

**`final-review.md`** — Final reviewer (IMPORTANT: fresh context only — no build history):
```markdown
# Final Review Agent Prompt

<identity>
You are a final review agent. You have NOT seen this code before.
You review it fresh, against the original requirements only.
</identity>

<mission>Final review of feature: {{MISSION}}</mission>

## Original Requirements
{{ORIGINAL_PRD}}

## Final Integrated Code
{{FINAL_CODE}}

## Test Results
{{TEST_RESULTS}}

<scope>
READ ONLY: provided code above.
DO NOT: request build history, prior review comments, or intermediate states.
Evaluate only: does this code satisfy the original requirements?
</scope>

## Output Contract

```
VERDICT: PASS | FAIL
FINDINGS:
  - [CRITICAL] file:line — description
  - [HIGH] file:line — description
BLOCKING_ISSUES: <list of issues that prevent completion>
SUMMARY: <one sentence overall assessment>
```
```

**Why:** Slot-filling templates make prompt assembly deterministic. The orchestrator fills slots from structured data (slice JSON, df-explain output, PRD) instead of composing prose. The `final-review.md` deliberately provides NO build history to prevent reviewer bias.

**Verify:**
```bash
ls skills/feature/agents/prompts/
# impl.md  test.md  slice-review.md  integration.md  final-review.md  _base.md

grep "SCOPE_FILES\|MISSION\|MEMORY_CONTEXT" skills/feature/agents/prompts/impl.md
grep "PASS | FAIL\|Output Contract" skills/feature/agents/prompts/slice-review.md
grep "build history\|fresh" skills/feature/agents/prompts/final-review.md
```

---

### Task 5.3 — Update Phase 3 to use prompt templates

**File(s):**
- Modify: `skills/feature/phases/phase-3-execution.md` — agent dispatch section

**What:**
Replace the prose "combine agent role + slice briefing + domain context" assembly instruction with explicit slot-filling instructions.

Replace the current "Assemble agent prompt" prose with:

```markdown
### Agent Prompt Assembly

Use the template from `skills/feature/agents/prompts/<type>.md`.
Fill slots in this order:

1. `{{MISSION}}` ← slice JSON `goal` field
2. `{{SCOPE_FILES}}` ← slice JSON `files[]` array (comma-separated)
3. `{{MEMORY_CONTEXT}}` ← output of `df-explain --rank --budget 512`
4. `{{SLICE_CONTEXT}}` ← contents of slice MD file
5. `{{PRIOR_WORK}}` ← previous attempt's output (ONLY on retry)
6. `{{PRIOR_FEEDBACK}}` ← reviewer findings from previous attempt (ONLY on retry)

Do NOT add additional context beyond these slots.
Do NOT inject conversation history into agent prompts.
Each agent receives only what its template specifies.

CHECKPOINT: "[DevFlow] Phase 3: prompt assembled for <agent-type> on slice <id>."
```

**Verify:**
```bash
grep "slot-filling\|MISSION.*←\|SCOPE_FILES.*←" skills/feature/phases/phase-3-execution.md
grep "CHECKPOINT.*prompt assembled" skills/feature/phases/phase-3-execution.md
```

---

### Task 5.4 — Create output validation pipeline

**File(s):**
- Create: `skills/feature/agents/output-validation.md`
- Modify: `skills/feature/phases/phase-3-execution.md` — add validation step after each agent call

**What:**
Create the validation pipeline spec and wire it into Phase 3.

`skills/feature/agents/output-validation.md`:

```markdown
# Output Validation Pipeline

Run after EVERY agent response, before the orchestrator accepts the result.
All checks are zero LLM cost (filesystem + git operations only).

## Validation Chain (ordered by cost, cheapest first)

| # | Check | Method | Catches |
|---|-------|--------|---------|
| 1 | Output format valid | Parse required fields from output | Malformed responses |
| 2 | File paths exist | `[[ -f "$path" ]]` for each path in FILES_CHANGED | Hallucinated paths |
| 3 | Scope check | `git diff --name-only` vs slice `files[]` allowlist | Scope creep |
| 4 | Non-empty | `git diff --stat` shows >0 lines changed | No-op submissions |
| 5 | Incomplete signals | grep for TODO, FIXME, `pass`, `throw new Error("Not implemented")`, `...` | Stub/placeholder code |
| 6 | Static analysis | `tsc --noEmit` or `lint_cmd` from config.json | Type errors, broken imports |
| 7 | Test execution | `test_cmd` from config.json | Actual runtime bugs |
| 8 | Slop score | prose-to-code ratio > 5:1 in output | Generic/unhelpful output |

## Routing

| Check Result | Type | Action |
|-------------|------|--------|
| Checks 1-4 fail | REJECT (hard) | Retry with format/scope reminder. Counts as a retry. |
| Checks 5-8 fail | RETRY (soft) | Retry with specific failure output as feedback |
| All pass | PROCEED | Send to next pipeline stage |
| `retry_count >= 3` | STUCK | Mark stuck, T3 gate |

## Issue Fingerprinting

After each retry, classify attempt result using fingerprints (`file:line:category`):

| Classification | Condition | Action |
|---------------|-----------|--------|
| CLEAN | No issues | → proceed immediately |
| PROGRESS | Fewer issues than last attempt | → continue retrying |
| MIXED | Some resolved + some new | → continue, escalate faster |
| STALLED | Same fingerprints persist | → mark stuck immediately |
| REGRESSION | New fingerprints + old persist | → mark stuck immediately |

Exit on STALLED or REGRESSION without consuming remaining retries.
```

Add to Phase 3 execution after each agent call:

```markdown
### After each agent response: run validation pipeline

Load `skills/feature/agents/output-validation.md`.
Run checks 1-8 in order. Stop at first failure.
Route per the routing table.

CHECKPOINT: "[DevFlow] Validation: <N>/8 checks passed. Result: <PROCEED|RETRY|STUCK>."
```

**Why:** Agent output is currently trusted at face value. Checks 1-4 catch objectively wrong outputs (hallucinated paths, scope creep) at zero cost. Checks 5-8 catch quality issues before they become hidden bugs.

**Verify:**
```bash
[[ -f skills/feature/agents/output-validation.md ]] && echo exists
grep "Validation Chain\|Issue Fingerprinting" skills/feature/agents/output-validation.md
grep "STALLED\|REGRESSION\|mark stuck immediately" skills/feature/agents/output-validation.md
grep "run validation pipeline\|CHECKPOINT.*Validation" skills/feature/phases/phase-3-execution.md
```

---

### Task 5.5 — Optional: Create /prompt skill

**File(s):**
- Create: `skills/prompt/SKILL.md` (optional — skip if scope is too broad)

**What:**
A lightweight skill for building custom agent prompts on-demand outside the feature flow. Useful when users want to dispatch ad-hoc agents for tasks not covered by the feature flow's built-in agents.

```markdown
---
name: prompt
requires: [mem-sync]
triggers_on_complete: []
---

# Skill: prompt

Build a development-focused agent prompt using DevFlow memory context.

## When to use
When: "I need an agent to do X" where X isn't one of the feature flow's built-in slices.

## Steps

### Step 1 — Classify task type [T1]

| Task description contains | Type |
|--------------------------|------|
| write, implement, create, add | executor |
| review, check, audit, analyze | reviewer |
| investigate, understand, explain | analyst |
| DEFAULT | executor |

### Step 2 — Load template [T1]

Load `skills/feature/agents/prompts/<type>.md`

### Step 3 — Fill slots [T2]

Fill `{{MEMORY_CONTEXT}}` from: `df-explain --rank --budget 512`
Fill `{{MISSION}}` from: user's description
Fill `{{SCOPE_FILES}}` from: user's file list OR ask (T3 if not provided)
Fill `{{SCOPE_PROHIBITIONS}}` from: template default for this type

Print filled prompt. Do not dispatch automatically.

## Output

A ready-to-use prompt. User copies and uses it.
```

**Note:** This task is optional. Include it if the prompting skill would be useful to you; skip it if it adds unnecessary scope.

**Verify:**
```bash
[[ -f skills/prompt/SKILL.md ]] && echo exists
grep "executor\|reviewer\|analyst" skills/prompt/SKILL.md
```

---

## Verification Gates

After all tasks complete:

- [ ] `skills/feature/agents/prompts/` exists with 6 files (5 templates + `_base.md`)
- [ ] Each template has `<scope>` fence, Output Contract, and `{{MISSION}}` slot
- [ ] `final-review.md` template does NOT contain `{{PRIOR_WORK}}` or build history slots
- [ ] Phase 3 has prompt assembly slot-filling instructions
- [ ] `output-validation.md` exists with 8-check pipeline
- [ ] STALLED/REGRESSION logic exists in `output-validation.md`
- [ ] Phase 3 references the validation pipeline
- [ ] All checks in validation pipeline are zero-LLM-cost (no AI calls):
  ```bash
  grep "LLM\|claude\|anthropic" skills/feature/agents/output-validation.md | wc -l
  # Expected: 0
  ```

## Rollback

```bash
rm -rf skills/feature/agents/prompts/
rm -f skills/feature/agents/output-validation.md
rm -rf skills/prompt/
git checkout HEAD -- skills/feature/phases/phase-3-execution.md
```
